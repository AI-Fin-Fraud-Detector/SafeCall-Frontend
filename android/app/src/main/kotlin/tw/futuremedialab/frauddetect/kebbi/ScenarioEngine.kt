package tw.futuremedialab.frauddetect.kebbi

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nuwarobotics.service.agent.NuwaRobotAPI

// 逐步播放動作腳本：燈光、音效、底盤、肢體動作同時觸發，再由計時器進到下一步。
class ScenarioEngine(
    private val robot: NuwaRobotAPI,
    private val chassisManager: ChassisSafetyManager,
    private val ledManager: LedManager,
    private val soundManager: SoundEffectManager?,
    private val isMotorEnabled: () -> Boolean,
) {

    companion object {
        private const val TAG = "[KebbiScenario]"

        // false：不要讓機器人的臉蓋住 App 畫面
        private const val AUTO_FADE_IN_FACE_WINDOW = false
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var watchdogRunnable: Runnable? = null

    @Volatile
    var currentScenario: Scenario? = null
        private set

    @Volatile
    var isPlaying: Boolean = false
        private set

    private var currentStepIndex: Int = -1

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
        mainHandler.post { executeStep(0) }
        return true
    }

    /** 全部停下並復原硬體 */
    @Synchronized
    fun stop() {
        if (!isPlaying && currentScenario == null) return

        Log.i(TAG, "stop ${currentScenario?.id}")
        cancelWatchdog()
        isPlaying = false
        currentStepIndex = -1
        currentScenario = null

        chassisManager.emergencyStop()

        try {
            if (isMotorEnabled()) robot.motionStop(false)
        } catch (t: Throwable) {
            Log.e(TAG, "motionStop failed", t)
        }

        ledManager.reset()
        soundManager?.stopAll()
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

        setWatchdog(step.timeoutMs) {
            Log.i(TAG, "step timed out: ${step.name}")
            executeStep(index + 1)
        }
    }

    private fun finish() {
        val finished = currentScenario ?: return
        Log.i(TAG, "finished ${finished.id}")

        cancelWatchdog()
        chassisManager.emergencyStop()
        ledManager.reset()
        soundManager?.stopAll()

        isPlaying = false
        currentStepIndex = -1
        currentScenario = null
    }

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
