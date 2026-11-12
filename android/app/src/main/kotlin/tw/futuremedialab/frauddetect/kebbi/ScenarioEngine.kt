package tw.futuremedialab.frauddetect.kebbi

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nuwarobotics.service.agent.NuwaRobotAPI

// 逐步播放動作腳本：燈光、音效、底盤、肢體動作同時觸發，再由計時器進到下一步。
// 另外支援 (從 KebbiScenarioPlayer 移植)：
// - 直接控制關節 (情緒動作)，送出前經 JointSafety 檢查
// - 維持姿勢 (holdAtMs)：內建動作播到姿勢就暫停，等 next() 再播完；維持期間有不規則浮動
// - 整個劇本期間的表情 (Scenario.face)
// - playAfterCurrent：等目前劇本播完再接下一個 (例如 聆聽→點頭 播完才開始思考)
class ScenarioEngine(
    private val robot: NuwaRobotAPI,
    private val chassisManager: ChassisSafetyManager,
    private val ledManager: LedManager,
    private val soundManager: SoundEffectManager?,
    private val isMotorEnabled: () -> Boolean,
    private val faceController: FaceController? = null,
) {

    companion object {
        private const val TAG = "[KebbiScenario]"

        // false：不要讓內建動作附帶的臉部影片蓋住 App 畫面 (表情改由 FaceController 控制)
        private const val AUTO_FADE_IN_FACE_WINDOW = false

        // 臉部畫面出現需要時間；有表情的劇本，動作也一起延後，讓兩者同時開始
        private const val FACE_DELAY_MS = 800L

        // 浮動結束後等關節回到暫停姿勢 (≤15° / 40°/s) 再繼續播完
        private const val WIGGLE_RESTORE_MS = 600L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var watchdogRunnable: Runnable? = null
    private val rng = java.util.Random()

    @Volatile
    var currentScenario: Scenario? = null
        private set

    @Volatile
    var isPlaying: Boolean = false
        private set

    private var currentStepIndex: Int = -1

    /** 目前劇本播完後要接著播的劇本 */
    private var queuedScenario: Scenario? = null

    /** 回傳 false 表示已經有動作在播 */
    @Synchronized
    fun play(scenario: Scenario): Boolean {
        if (isPlaying) {
            Log.i(TAG, "busy with ${currentScenario?.id}, skipping ${scenario.id}")
            return false
        }
        if (!isMotorEnabled()) {
            Log.w(TAG, "motors disabled, skipping ${scenario.id}")
            return false
        }

        isPlaying = true
        currentScenario = scenario
        currentStepIndex = 0

        Log.i(TAG, "start ${scenario.id} (${scenario.steps.size} steps)")
        val face = scenario.face
        if (face != null && faceController != null) {
            faceController.show(face.name)
            mainHandler.postDelayed({
                if (isPlaying && currentScenario === scenario) executeStep(0)
            }, FACE_DELAY_MS)
        } else {
            mainHandler.post { executeStep(0) }
        }
        return true
    }

    /**
     * 目前沒在播就立刻播；正在播就排在後面，等目前劇本播完再播 (只保留最後一個排隊的)。
     * 回傳 true 表示已開始或已排入。
     */
    @Synchronized
    fun playAfterCurrent(scenario: Scenario): Boolean {
        if (!isPlaying) return play(scenario)
        Log.i(TAG, "queue ${scenario.id} after ${currentScenario?.id}")
        queuedScenario = scenario
        return true
    }

    /** 全部停下並復原硬體 */
    @Synchronized
    fun stop() {
        queuedScenario = null
        if (!isPlaying && currentScenario == null) return

        val stopped = currentScenario
        Log.i(TAG, "stop ${stopped?.id}")
        cancelWatchdog()
        cancelHold()
        isPlaying = false
        currentStepIndex = -1
        currentScenario = null

        chassisManager.emergencyStop()

        try {
            if (isMotorEnabled()) robot.motionStop(false)
        } catch (t: Throwable) {
            Log.e(TAG, "motionStop failed", t)
        }

        returnJointsToReference(stopped)
        if (stopped?.face != null) faceController?.reset()
        ledManager.reset()
        soundManager?.stopAll()
    }

    /**
     * 結束目前的「維持姿勢」，讓內建動作播完回到立正再進下一步
     * (管家頁面：回覆到了 / 長輩說完了)。沒有在維持就回傳 false。
     */
    @Synchronized
    fun next(): Boolean {
        if (!isPlaying) return false
        val step = currentScenario?.steps?.getOrNull(currentStepIndex) ?: return false
        if (step.holdAtMs == null || holdReleased) return false
        Log.i(TAG, "next(): releasing hold on ${step.name}")
        mainHandler.post { releaseHold() }
        return true
    }

    private fun executeStep(index: Int) {
        val scenario = currentScenario ?: return
        if (index >= scenario.steps.size) {
            finish()
            return
        }

        currentStepIndex = index
        val step = scenario.steps[index]
        Log.i(TAG, "step ${index + 1}/${scenario.steps.size}: ${step.name}")

        ledManager.applyPattern(step.ledPattern)

        step.soundType?.let { soundManager?.play(it) }

        step.chassisMove?.let { chassisManager.execute(it) }

        step.motionName?.let { motion ->
            if (isMotorEnabled()) {
                try {
                    robot.motionPlay(motion, AUTO_FADE_IN_FACE_WINDOW)
                } catch (t: Throwable) {
                    Log.e(TAG, "motionPlay failed for $motion", t)
                }
            }
        }

        if (step.jointTargets.isNotEmpty() && isMotorEnabled()) {
            sendJointTargets(step.jointTargets)
        }

        // 維持姿勢：播到 holdAtMs 暫停，等 next()
        cancelHold()
        holdReleased = false
        val holdAt = step.holdAtMs
        if (holdAt != null && step.motionName != null) {
            val r = Runnable {
                if (isPlaying && currentStepIndex == index && !holdReleased) {
                    try {
                        robot.motionPause()
                        holdPaused = true
                        Log.i(TAG, "hold: paused ${step.motionName} at ${holdAt}ms")
                        startWiggle(step.holdWiggle)
                    } catch (t: Throwable) {
                        Log.e(TAG, "motionPause failed", t)
                    }
                }
            }
            holdRunnable = r
            mainHandler.postDelayed(r, holdAt)
            // 最長維持時間到了就自己放開
            setWatchdog(step.timeoutMs) {
                Log.i(TAG, "hold timed out: ${step.name}")
                releaseHold()
            }
            return
        }

        setWatchdog(step.timeoutMs) {
            Log.i(TAG, "step timed out: ${step.name}")
            executeStep(index + 1)
        }
    }

    private fun finish() {
        val finished = currentScenario ?: return
        Log.i(TAG, "finished ${finished.id}")

        cancelWatchdog()
        cancelHold()
        chassisManager.emergencyStop()
        if (finished.face != null) faceController?.reset()
        ledManager.reset()
        soundManager?.stopAll()

        isPlaying = false
        currentStepIndex = -1
        currentScenario = null

        val queued = queuedScenario
        queuedScenario = null
        if (queued != null) {
            Log.i(TAG, "starting queued ${queued.id}")
            play(queued)
        }
    }

    // ── 關節直接控制 ───────────────────────────────────────────────────────────

    private fun sendJointTargets(targets: List<JointTarget>) {
        targets.forEach { t ->
            if (!JointSafety.isAllowed(t)) {
                Log.e(TAG, "joint REJECTED motor=${t.motorId} deg=${t.degree} speed=${t.speed}")
                return@forEach
            }
            try {
                robot.ctlMotor(t.motorId, t.degree, t.speed)
            } catch (e: Exception) {
                Log.e(TAG, "ctlMotor failed motor=${t.motorId}", e)
            }
        }
    }

    /** 中途停止時，把這個劇本直接控制過的關節送回 0 */
    private fun returnJointsToReference(scenario: Scenario?) {
        val motors = scenario?.steps?.flatMap { s -> s.jointTargets.map { it.motorId } }?.toSet().orEmpty()
        if (motors.isEmpty() || !isMotorEnabled()) return
        sendJointTargets(motors.map { JointTarget(it, 0f) })
    }

    // ── 維持姿勢 ───────────────────────────────────────────────────────────────

    private var holdRunnable: Runnable? = null
    @Volatile private var holdPaused = false
    @Volatile private var holdReleased = false

    private fun cancelHold() {
        holdRunnable?.let { mainHandler.removeCallbacks(it) }
        holdRunnable = null
        holdPaused = false
        stopWiggle(restore = false)
    }

    private fun releaseHold() {
        if (holdReleased) return
        holdReleased = true
        val wasPaused = holdPaused
        val hadWiggle = wiggleRunnables.isNotEmpty()
        stopWiggle(restore = true)
        cancelHold()
        val resumeDelay = if (wasPaused && hadWiggle) WIGGLE_RESTORE_MS else 0L
        if (wasPaused) {
            mainHandler.postDelayed({
                try { robot.motionResume() } catch (t: Throwable) { Log.e(TAG, "motionResume failed", t) }
            }, resumeDelay)
        }
        val index = currentStepIndex
        val step = currentScenario?.steps?.getOrNull(index)
        val afterMs = resumeDelay + (step?.afterReleaseMs ?: 1000L)
        Log.i(TAG, "hold released (paused=$wasPaused), next step in ${afterMs}ms")
        setWatchdog(afterMs) { executeStep(index + 1) }
    }

    // ── 維持姿勢時的不規則浮動 ─────────────────────────────────────────────────

    private val wiggleRunnables = mutableListOf<Runnable>()
    private var wiggleBase: Map<Int, Float> = emptyMap()

    private fun startWiggle(wiggles: List<Wiggle>) {
        if (wiggles.isEmpty() || !isMotorEnabled()) return
        wiggleBase = wiggles.associate { w ->
            w.motorId to try { robot.getMotorPresentPositionInDegree(w.motorId) } catch (e: Exception) { Float.NaN }
        }
        Log.i(TAG, "wiggle base: $wiggleBase")
        wiggles.forEach { w ->
            var lastOffset = 0f
            val r = object : Runnable {
                override fun run() {
                    val base = wiggleBase[w.motorId] ?: Float.NaN
                    val span = w.maxOffset - w.minOffset
                    var offset: Float
                    var tries = 0
                    do {
                        offset = w.minOffset + rng.nextFloat() * span
                        tries++
                    } while (kotlin.math.abs(offset - lastOffset) < span * 0.4f && tries < 6)
                    lastOffset = offset
                    val target = base + offset
                    if (JointSafety.isWiggleAllowed(w.motorId, base, target, w.speed)) {
                        try { robot.ctlMotor(w.motorId, target, w.speed) } catch (e: Exception) { Log.e(TAG, "wiggle failed", e) }
                    } else {
                        Log.w(TAG, "wiggle REJECTED motor=${w.motorId} base=$base target=$target")
                    }
                    val moveMs = (kotlin.math.abs(offset) / w.speed * 1000).toLong()
                    val dwell = w.minDwellMs + (rng.nextDouble() * (w.maxDwellMs - w.minDwellMs)).toLong()
                    mainHandler.postDelayed(this, moveMs + dwell)
                }
            }
            wiggleRunnables.add(r)
            mainHandler.postDelayed(r, (rng.nextDouble() * 600).toLong())
        }
    }

    /** restore=true：送回暫停當下的角度，讓 motionResume 從原姿勢接續 */
    private fun stopWiggle(restore: Boolean) {
        wiggleRunnables.forEach { mainHandler.removeCallbacks(it) }
        wiggleRunnables.clear()
        if (restore && isMotorEnabled()) {
            wiggleBase.forEach { (m, base) ->
                if (JointSafety.isWiggleAllowed(m, base, base, JointSafety.MAX_WIGGLE_SPEED)) {
                    try { robot.ctlMotor(m, base, JointSafety.MAX_WIGGLE_SPEED) } catch (e: Exception) { Log.e(TAG, "wiggle restore failed", e) }
                }
            }
        }
        wiggleBase = emptyMap()
    }

    // ── watchdog ──────────────────────────────────────────────────────────────

    private fun setWatchdog(timeoutMs: Long, onTimeout: () -> Unit) {
        cancelWatchdog()
        val r = Runnable { onTimeout() }
        watchdogRunnable = r
        mainHandler.postDelayed(r, timeoutMs)
    }

    private fun cancelWatchdog() {
        watchdogRunnable?.let {
            mainHandler.removeCallbacks(it)
            watchdogRunnable = null
        }
    }
}
