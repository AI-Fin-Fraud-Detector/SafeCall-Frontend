package tw.futuremedialab.frauddetect.kebbi

import android.media.AudioAttributes
import android.media.SoundPool
import android.util.Log
import java.io.File

// Android 內建音效。檔案不存在就跳過，動作照跑。
class SoundEffectManager {

    companion object {
        private const val TAG = "[KebbiSound]"

        private val SOUND_FILES = mapOf(
            SoundType.TADA to "/system/media/audio/notifications/TaDa.ogg",
            SoundType.ALARM_BUZZER to "/system/media/audio/alarms/Alarm_Buzzer.ogg",
            SoundType.VERY_ALARMED to "/system/media/audio/ringtones/VeryAlarmed.ogg",
            SoundType.DING to "/system/media/audio/ringtones/Ding.ogg",
        )
    }

    private var soundPool: SoundPool? = null
    private val soundIds = mutableMapOf<SoundType, Int>()

    init {
        try {
            val attrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()

            val pool = SoundPool.Builder()
                .setMaxStreams(4)
                .setAudioAttributes(attrs)
                .build()
            soundPool = pool

            SOUND_FILES.forEach { (type, path) ->
                if (File(path).exists()) {
                    soundIds[type] = pool.load(path, 1)
                } else {
                    Log.w(TAG, "sound file not found: $path")
                }
            }
        } catch (t: Throwable) {
            Log.e(TAG, "failed to initialise SoundPool", t)
        }
    }

    fun play(type: SoundType, volume: Float = 1.0f) {
        val pool = soundPool ?: return
        val id = soundIds[type] ?: return
        try {
            pool.play(id, volume, volume, 1, 0, 1.0f)
        } catch (t: Throwable) {
            Log.e(TAG, "failed to play $type", t)
        }
    }

    fun stopAll() {
        try {
            soundPool?.autoPause()
        } catch (t: Throwable) {
            Log.e(TAG, "stopAll failed", t)
        }
    }

    fun release() {
        try {
            soundPool?.release()
        } catch (t: Throwable) {
            Log.e(TAG, "release failed", t)
        } finally {
            soundPool = null
            soundIds.clear()
        }
    }
}
