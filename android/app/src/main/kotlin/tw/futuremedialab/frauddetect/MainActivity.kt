package tw.futuremedialab.frauddetect

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.nuwarobotics.service.IClientId
import com.nuwarobotics.service.agent.NuwaRobotAPI
import com.nuwarobotics.service.agent.RobotEventCallback
import com.nuwarobotics.service.agent.VoiceEventCallback
import com.nuwarobotics.service.agent.VoiceEventListener
import org.vosk.Model
import org.vosk.Recognizer
import org.vosk.android.RecognitionListener
import org.vosk.android.SpeechService
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.zip.ZipInputStream
import tw.futuremedialab.frauddetect.kebbi.ChassisSafetyManager
import tw.futuremedialab.frauddetect.kebbi.FaceController
import tw.futuremedialab.frauddetect.kebbi.LedManager
import tw.futuremedialab.frauddetect.kebbi.ScenarioEngine
import tw.futuremedialab.frauddetect.kebbi.ScenarioRepository
import tw.futuremedialab.frauddetect.kebbi.SoundEffectManager

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "kebbi"
        private const val TAG = "[KebbiMain]"
        private const val ACTION_RAISE_RIGHT_ARM = "666_BA_RArmS90"
        private const val SCENARIO_FRAUD = "fraud_siren"
        private const val SCENARIO_SAFE = "butler_celebrate"

        // 預設關閉。動作會讓機器人以約 0.3 m/s 移動，放在桌上會掉下去。
        // Flutter 端用 setChassisEnabled 開啟。
        private const val CHASSIS_ENABLED_BY_DEFAULT = false
        private const val VOSK_MODEL_NAME = "vosk-model-small-en-us-0.15"
        private const val VOSK_MODEL_URL =
            "https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip"
    }

    private var robotApi: Any? = null
    private var methodChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    // 動作播放
    private var scenarioEngine: ScenarioEngine? = null
    private var soundManager: SoundEffectManager? = null
    private var faceController: FaceController? = null
    @Volatile private var chassisEnabled = CHASSIS_ENABLED_BY_DEFAULT

    // Vosk
    private var voskModel: Model? = null
    private var voskSpeechService: SpeechService? = null
    @Volatile private var voskDownloading = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ensureRobotApi()
        // 臉部服務連線是非同步的，啟動時就先建立，第一次換臉時才會已連上
        if (faceController == null) faceController = FaceController(applicationContext)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = ch

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    try {
                        ensureRobotApi()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "init error", t)
                        result.error("INIT_FAIL", t.message, null)
                    }
                }

                "fraud" -> playScenario(SCENARIO_FRAUD, result)

                "safe" -> playScenario(SCENARIO_SAFE, result)

                "playScenario" -> {
                    val id = call.argument<String>("id")
                    if (id.isNullOrBlank()) {
                        result.error("BAD_ARGS", "scenario id is required", null)
                    } else {
                        playScenario(id, result)
                    }
                }

                // 等目前的動作播完再播 (例如 聆聽→點頭 播完才開始思考)
                "playScenarioAfterCurrent" -> {
                    val id = call.argument<String>("id")
                    val scenario = id?.let { ScenarioRepository.findById(it) }
                    val engine = ensureScenarioEngine()
                    when {
                        scenario == null -> result.error("NO_SCENARIO", "Unknown scenario id: $id", null)
                        engine == null -> result.success(false)
                        else -> result.success(engine.playAfterCurrent(scenario))
                    }
                }

                // 結束目前的「維持姿勢」(回覆到了 / 長輩說完了)
                "nextScenarioStep" -> {
                    result.success(scenarioEngine?.next() ?: false)
                }

                "stopScenario" -> {
                    try {
                        scenarioEngine?.stop()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "stopScenario error", t)
                        result.error("STOP_FAIL", t.message, null)
                    }
                }

                "isScenarioPlaying" -> {
                    result.success(scenarioEngine?.isPlaying ?: false)
                }

                "listScenarios" -> {
                    result.success(
                        ScenarioRepository.allScenarios.map {
                            mapOf(
                                "id" to it.id,
                                "title" to it.title,
                                "category" to it.category.name,
                                "description" to it.description,
                            )
                        }
                    )
                }

                "setChassisEnabled" -> {
                    chassisEnabled = call.argument<Boolean>("enabled") ?: false
                    Log.i(TAG, "chassis driving enabled = $chassisEnabled")
                    result.success(chassisEnabled)
                }

                "checkKebbi" -> {
                    ensureRobotApi()
                    result.success(robotApi != null)
                }

                "startSTT" -> {
                    try {
                        ensureRobotApi()
                        val api = robotApi
                        if (api == null) {
                            result.error("NOT_READY", "Robot API not initialized", null)
                        } else {
                            startSTT(api)
                            result.success(null)
                        }
                    } catch (t: Throwable) {
                        Log.e(TAG, "startSTT error", t)
                        result.error("STT_START_FAIL", t.message, null)
                    }
                }

                "stopSTT" -> {
                    try {
                        val api = robotApi
                        if (api != null) stopSTT(api)
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "stopSTT error", t)
                        result.error("STT_STOP_FAIL", t.message, null)
                    }
                }

                "release" -> {
                    try {
                        releaseRobotApi()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "release error", t)
                        result.error("RELEASE_FAIL", t.message, null)
                    }
                }

                // ── Vosk ──────────────────────────────────────────────────────────

                "checkVoskModel" -> {
                    val modelDir = File(filesDir, VOSK_MODEL_NAME)
                    result.success(modelDir.exists() && modelDir.isDirectory)
                }

                "initVosk" -> {
                    initVosk(result)
                }

                "startVoskSTT" -> {
                    try {
                        startVoskSTT()
                        result.success(null)
                    } catch (t: Throwable) {
                        Log.e(TAG, "startVoskSTT error", t)
                        result.error("VOSK_STT_FAIL", t.message, null)
                    }
                }

                "stopVoskSTT" -> {
                    try {
                        stopVoskSTT()
                        result.success(null)
                    } catch (t: Throwable) {
                        result.error("VOSK_STOP_FAIL", t.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    // ── Kebbi STT ──────────────────────────────────────────────────────────────

    private fun startSTT(api: Any) {
        val robot = api as? NuwaRobotAPI
        if (robot != null) {
            try {
                robot.registerVoiceEventListener(object : VoiceEventCallback() {
                    override fun onSpeech2TextComplete(isError: Boolean, text: String?) {
                        Log.d(TAG, "onSpeech2TextComplete: rawText=$text isError=$isError")
                        if (!isError && !text.isNullOrBlank()) {
                            val cleanText = try {
                                com.nuwarobotics.service.agent.VoiceResultJsonParser.parseVoiceResult(text)
                            } catch (_: Throwable) {
                                null
                            }?.ifBlank { null } ?: try {
                                org.json.JSONObject(text).optString("result", text)
                            } catch (_: Throwable) {
                                text
                            }
                            Log.d(TAG, "onSpeech2TextComplete: cleanText=$cleanText")
                            mainHandler.post {
                                methodChannel?.invokeMethod(
                                    "onSTTResult",
                                    mapOf("text" to cleanText, "isFinal" to true)
                                )
                            }
                        } else {
                            Log.w(TAG, "onSpeech2TextComplete error or empty: isError=$isError")
                            mainHandler.post {
                                methodChannel?.invokeMethod(
                                    "onSTTResult",
                                    mapOf("text" to "", "isFinal" to true)
                                )
                            }
                        }
                    }

                    override fun onSpeechState(
                        listenType: VoiceEventListener.ListenType?,
                        speechState: VoiceEventListener.SpeechState?
                    ) {
                        Log.d(TAG, "onSpeechState: type=$listenType state=$speechState")
                    }
                })
                Log.d(TAG, "registerVoiceEventListener OK")
            } catch (t: Throwable) {
                Log.w(TAG, "registerVoiceEventListener failed", t)
            }

            try {
                robot.startSpeech2Text(false)
                Log.d(TAG, "startSpeech2Text OK")
            } catch (t: Throwable) {
                Log.e(TAG, "startSpeech2Text failed", t)
                throw t
            }
            return
        }
    }

    private fun stopSTT(api: Any) {
        val robot = api as? NuwaRobotAPI
        if (robot != null) {
            try {
                robot.stopListen()
                Log.d(TAG, "stopListen OK")
            } catch (t: Throwable) {
                Log.w(TAG, "stopListen failed: ${t.message}")
            }
            return
        }
    }

    // ── Vosk offline STT ───────────────────────────────────────────────────────

    private fun initVosk(result: MethodChannel.Result) {
        val modelDir = File(filesDir, VOSK_MODEL_NAME)

        if (modelDir.exists() && modelDir.isDirectory) {
            // Already on disk — just load
            Thread {
                try {
                    if (voskModel == null) {
                        voskModel = Model(modelDir.absolutePath)
                    }
                    Log.d(TAG, "Vosk model loaded from cache")
                    mainHandler.post { result.success(null) }
                } catch (e: Exception) {
                    Log.e(TAG, "Vosk model load error", e)
                    mainHandler.post { result.error("VOSK_LOAD_FAIL", e.message, null) }
                }
            }.start()
            return
        }

        // Guard against concurrent downloads
        if (voskDownloading) {
            result.error("VOSK_BUSY", "Model is already downloading", null)
            return
        }
        voskDownloading = true

        // Download → unzip → load
        Thread {
            val zipFile = File(cacheDir, "$VOSK_MODEL_NAME.zip")
            try {
                // ── Download ─────────────────────────────────────────
                Log.d(TAG, "Downloading Vosk model from $VOSK_MODEL_URL")
                val conn = URL(VOSK_MODEL_URL).openConnection() as HttpURLConnection
                conn.connectTimeout = 15_000
                conn.readTimeout = 60_000
                conn.connect()
                val total = conn.contentLength.toLong()
                Log.d(TAG, "Vosk model size: $total bytes")

                FileOutputStream(zipFile).use { fos ->
                    conn.inputStream.use { input ->
                        val buf = ByteArray(16_384)
                        var downloaded = 0L
                        var lastProgress = -1
                        var n: Int
                        while (input.read(buf).also { n = it } != -1) {
                            fos.write(buf, 0, n)
                            downloaded += n
                            if (total > 0) {
                                val progress = (downloaded * 100 / total).toInt()
                                if (progress != lastProgress) {
                                    lastProgress = progress
                                    mainHandler.post {
                                        methodChannel?.invokeMethod("onVoskProgress", progress)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Unzip ─────────────────────────────────────────────
                Log.d(TAG, "Extracting Vosk model…")
                mainHandler.post { methodChannel?.invokeMethod("onVoskProgress", -1) }
                unzip(zipFile, filesDir)
                zipFile.delete()
                Log.d(TAG, "Vosk model extracted")

                // ── Load ──────────────────────────────────────────────
                voskModel = Model(File(filesDir, VOSK_MODEL_NAME).absolutePath)
                Log.d(TAG, "Vosk model loaded successfully")
                voskDownloading = false
                mainHandler.post { result.success(null) }

            } catch (e: Exception) {
                Log.e(TAG, "initVosk failed", e)
                zipFile.delete()
                voskDownloading = false
                mainHandler.post { result.error("VOSK_INIT_FAIL", e.message, null) }
            }
        }.start()
    }

    private fun startVoskSTT() {
        val model = voskModel ?: throw IllegalStateException("Vosk model not loaded")

        voskSpeechService?.apply { stop(); shutdown() }
        voskSpeechService = null

        val recognizer = Recognizer(model, 16000.0f)
        val service = SpeechService(recognizer, 16000.0f)
        voskSpeechService = service

        service.startListening(object : RecognitionListener {
            override fun onPartialResult(hypothesis: String?) {
                val text = parseVoskJson(hypothesis, "partial") ?: return
                if (text.isBlank()) return
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to text, "isFinal" to false)
                    )
                }
            }

            override fun onResult(hypothesis: String?) {
                val text = parseVoskJson(hypothesis, "text") ?: ""
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to text, "isFinal" to true)
                    )
                }
            }

            override fun onFinalResult(hypothesis: String?) {
                val text = parseVoskJson(hypothesis, "text") ?: ""
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to text, "isFinal" to true)
                    )
                }
            }

            override fun onError(exception: Exception?) {
                Log.e(TAG, "Vosk recognition error", exception)
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to "", "isFinal" to true)
                    )
                }
            }

            override fun onTimeout() {
                mainHandler.post {
                    methodChannel?.invokeMethod(
                        "onSTTResult", mapOf("text" to "", "isFinal" to true)
                    )
                }
            }
        })
        Log.d(TAG, "Vosk STT started")
    }

    private fun stopVoskSTT() {
        voskSpeechService?.apply { stop(); shutdown() }
        voskSpeechService = null
        Log.d(TAG, "Vosk STT stopped")
    }

    private fun unzip(zipFile: File, destDir: File) {
        ZipInputStream(zipFile.inputStream()).use { zis ->
            var entry = zis.nextEntry
            while (entry != null) {
                val outFile = File(destDir, entry.name)
                if (entry.isDirectory) {
                    outFile.mkdirs()
                } else {
                    outFile.parentFile?.mkdirs()
                    FileOutputStream(outFile).use { fos -> zis.copyTo(fos) }
                }
                zis.closeEntry()
                entry = zis.nextEntry
            }
        }
    }

    /** Simple regex-based JSON field extractor for Vosk output. */
    private fun parseVoskJson(json: String?, key: String): String? {
        if (json == null) return null
        return "\"$key\"\\s*:\\s*\"([^\"]*)\"".toRegex().find(json)?.groupValues?.getOrNull(1)
    }

    /** 回傳 false 表示已經有動作在播。引擎建不起來時退回原本的舉右手。 */
    private fun playScenario(id: String, result: MethodChannel.Result) {
        try {
            val scenario = ScenarioRepository.findById(id)
            if (scenario == null) {
                result.error("NO_SCENARIO", "Unknown scenario id: $id", null)
                return
            }

            val engine = ensureScenarioEngine()
            if (engine != null) {
                if (engine.isPlaying) {
                    engine.stop()
                }
                result.success(engine.play(scenario))
                return
            }

            // 拿不到 robot API，退回原本的行為
            Log.w(TAG, "scenario engine unavailable, falling back to single motion")
            ensureRobotApi()
            if (playMotion(ACTION_RAISE_RIGHT_ARM)) {
                result.success(true)
            } else {
                result.error("ACTION_FAIL", "Robot API not ready", null)
            }
        } catch (t: Throwable) {
            Log.e(TAG, "playScenario($id) error", t)
            result.error("ACTION_FAIL", t.message, null)
        }
    }

    /** 用跟 STT 同一個 NuwaRobotAPI，避免兩邊搶機器人。 */
    private fun ensureScenarioEngine(): ScenarioEngine? {
        scenarioEngine?.let { return it }

        ensureRobotApi()
        val robot = robotApi as? NuwaRobotAPI
        if (robot == null) {
            Log.w(TAG, "no NuwaRobotAPI instance; scenarios disabled")
            return null
        }

        return try {
            val sounds = soundManager ?: SoundEffectManager().also { soundManager = it }
            val face = faceController ?: FaceController(applicationContext).also { faceController = it }
            val engine = ScenarioEngine(
                robot = robot,
                chassisManager = ChassisSafetyManager(robot) { chassisEnabled },
                ledManager = LedManager(robot) { true },
                soundManager = sounds,
                isMotorEnabled = { true },
                faceController = face,
            )
            scenarioEngine = engine
            Log.i(TAG, "scenario engine ready (chassis=$chassisEnabled)")
            engine
        } catch (t: Throwable) {
            Log.e(TAG, "failed to build scenario engine", t)
            null
        }
    }

    // ── Robot API ──────────────────────────────────────────────────────────────

    private fun ensureRobotApi() {
        if (robotApi != null) return
        try {
            val clientId = IClientId(applicationContext.packageName)
            val api = NuwaRobotAPI(applicationContext, clientId)
            api.registerRobotEventListener(object : RobotEventCallback() {
                override fun onWikiServiceStart() {
                    Log.i(TAG, "Nuwa robot service connected (onWikiServiceStart)")
                }
                override fun onWikiServiceStop() {
                    Log.w(TAG, "Nuwa robot service stopped (onWikiServiceStop)")
                }
            })
            robotApi = api
            Log.i(TAG, "ensureRobotApi: NuwaRobotAPI created successfully")
        } catch (t: Throwable) {
            Log.e(TAG, "ensureRobotApi failed", t)
            robotApi = null
        }
    }

    private fun playMotion(motionName: String): Boolean {
        val robot = robotApi as? NuwaRobotAPI ?: return false
        return try {
            robot.motionPlay(motionName, false)
            Log.d(TAG, "motionPlay => $motionName")
            true
        } catch (t: Throwable) {
            Log.e(TAG, "motionPlay failed: $motionName", t)
            false
        }
    }

    private fun releaseRobotApi() {
        val robot = robotApi as? NuwaRobotAPI
        try {
            robot?.release()
        } catch (t: Throwable) {
            Log.w(TAG, "releaseRobotApi invoke error", t)
        } finally {
            robotApi = null
        }
    }

    override fun onDestroy() {
        voskSpeechService?.apply { stop(); shutdown() }
        voskModel?.close()
        scenarioEngine?.stop()
        scenarioEngine = null
        soundManager?.release()
        soundManager = null
        releaseRobotApi()
        super.onDestroy()
    }
}
