package tw.futuremedialab.frauddetect.kebbi

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nuwarobotics.service.agent.NuwaRobotAPI

// 限制速度、轉速與時長，並保證一定會停下來。
class ChassisSafetyManager(
    private val robot: NuwaRobotAPI,
    private val isChassisEnabled: () -> Boolean,
) {

    companion object {
        private const val TAG = "[KebbiChassis]"

        const val MAX_MOVE_SPEED = 0.32f
        const val MAX_TURN_SPEED = 150.0f
        const val MAX_DURATION_MS = 2500L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentStopRunnable: Runnable? = null

    @Volatile
    var isMoving: Boolean = false
        private set

    @Synchronized
    fun execute(move: ChassisMove, onComplete: (() -> Unit)? = null) {
        if (!isChassisEnabled()) {
            Log.i(TAG, "chassis move skipped: driving is disabled")
            onComplete?.invoke()
            return
        }

        emergencyStop()

        val speed = move.speed.coerceIn(-MAX_MOVE_SPEED, MAX_MOVE_SPEED)
        val turn = move.turnSpeed.coerceIn(-MAX_TURN_SPEED, MAX_TURN_SPEED)
        val duration = move.durationMs.coerceIn(0L, MAX_DURATION_MS)

        if ((speed == 0f && turn == 0f) || duration <= 0L) {
            onComplete?.invoke()
            return
        }

        isMoving = true
        Log.i(TAG, "moving: speed=$speed m/s turn=$turn deg/s for $duration ms")

        try {
            if (speed != 0f) robot.move(speed)
            if (turn != 0f) robot.turn(turn)
        } catch (t: Throwable) {
            Log.e(TAG, "failed to start chassis movement", t)
            emergencyStop()
            onComplete?.invoke()
            return
        }

        val stopRunnable = Runnable {
            emergencyStop()
            onComplete?.invoke()
        }
        currentStopRunnable = stopRunnable
        mainHandler.postDelayed(stopRunnable, duration)
    }

    @Synchronized
    fun emergencyStop() {
        currentStopRunnable?.let {
            mainHandler.removeCallbacks(it)
            currentStopRunnable = null
        }
        isMoving = false

        try {
            robot.move(0f)
            robot.turn(0f)
        } catch (t: Throwable) {
            Log.e(TAG, "chassis emergency stop failed", t)
        }
    }
}
