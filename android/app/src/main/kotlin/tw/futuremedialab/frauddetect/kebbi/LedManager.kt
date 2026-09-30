package tw.futuremedialab.frauddetect.kebbi

import android.os.Handler
import android.os.Looper
import android.util.Log
import com.nuwarobotics.service.agent.NuwaRobotAPI

class LedManager(
    private val robot: NuwaRobotAPI,
    private val isLedEnabled: () -> Boolean,
) {

    companion object {
        private const val TAG = "[KebbiLed]"

        private const val LED_HEAD = 1
        private const val LED_CHEST = 2
        private const val LED_RIGHT_HAND = 3
        private const val LED_LEFT_HAND = 4
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var currentLoopRunnable: Runnable? = null
    private var tick = 0

    @Synchronized
    fun applyPattern(pattern: LedPattern) {
        stopLoop()
        if (!isLedEnabled()) return

        when (pattern) {
            LedPattern.OFF -> reset()
            LedPattern.BREATH_GOLD -> setAllLeds(255, 180, 20)
            LedPattern.CYAN_FLOW -> setAllLeds(0, 220, 255)
            LedPattern.PURPLE_PULSE -> setAllLeds(180, 30, 255)
            LedPattern.SOFT_WHITE -> setAllLeds(200, 200, 200)
            LedPattern.SOLID_DARK_RED -> setAllLeds(255, 0, 0)

            LedPattern.RAINBOW -> {
                val colors = listOf(
                    Triple(255, 0, 0),
                    Triple(255, 127, 0),
                    Triple(255, 255, 0),
                    Triple(0, 255, 0),
                    Triple(0, 150, 255),
                    Triple(160, 32, 240),
                )
                startLoop(250L) {
                    val c = colors[tick % colors.size]
                    setAllLeds(c.first, c.second, c.third)
                }
            }

            LedPattern.RED_STROBE -> startLoop(150L) {
                if (tick % 2 == 0) setAllLeds(255, 0, 0) else setAllLeds(0, 0, 0)
            }

            LedPattern.RED_WHITE_ALERT -> startLoop(220L) {
                if (tick % 2 == 0) setAllLeds(255, 0, 0) else setAllLeds(255, 255, 255)
            }

            LedPattern.RED_AMBER_PULSE -> startLoop(300L) {
                if (tick % 2 == 0) setAllLeds(255, 0, 0) else setAllLeds(255, 80, 0)
            }

            LedPattern.POLICE_SIREN -> startLoop(180L) {
                val headRed = tick % 2 == 0
                val head = if (headRed) Triple(255, 0, 0) else Triple(0, 0, 255)
                val hand = if (headRed) Triple(0, 0, 255) else Triple(255, 0, 0)
                setIndividualLed(LED_HEAD, head.first, head.second, head.third)
                setIndividualLed(LED_CHEST, head.first, head.second, head.third)
                setIndividualLed(LED_LEFT_HAND, head.first, head.second, head.third)
                setIndividualLed(LED_RIGHT_HAND, hand.first, hand.second, hand.third)
            }
        }
    }

    @Synchronized
    fun reset() {
        stopLoop()
        try {
            robot.setLedColor(LED_HEAD, 0, 0, 0, 0)
            robot.setLedColor(LED_CHEST, 0, 0, 0, 0)
            robot.setLedColor(LED_RIGHT_HAND, 0, 0, 0, 0)
            robot.setLedColor(LED_LEFT_HAND, 0, 0, 0, 0)
            robot.enableSystemLED()
        } catch (t: Throwable) {
            Log.e(TAG, "failed to reset LEDs", t)
        }
    }

    private fun startLoop(intervalMs: Long, body: () -> Unit) {
        tick = 0
        val runnable = object : Runnable {
            override fun run() {
                body()
                tick++
                mainHandler.postDelayed(this, intervalMs)
            }
        }
        currentLoopRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun stopLoop() {
        currentLoopRunnable?.let {
            mainHandler.removeCallbacks(it)
            currentLoopRunnable = null
        }
    }

    private fun setAllLeds(r: Int, g: Int, b: Int) {
        try {
            robot.disableSystemLED()
            robot.setLedColor(LED_HEAD, 255, r, g, b)
            robot.setLedColor(LED_CHEST, 255, r, g, b)
            robot.setLedColor(LED_RIGHT_HAND, 255, r, g, b)
            robot.setLedColor(LED_LEFT_HAND, 255, r, g, b)
        } catch (t: Throwable) {
            Log.e(TAG, "setAllLeds failed", t)
        }
    }

    private fun setIndividualLed(id: Int, r: Int, g: Int, b: Int) {
        try {
            robot.disableSystemLED()
            robot.setLedColor(id, 255, r, g, b)
        } catch (t: Throwable) {
            Log.e(TAG, "setIndividualLed failed", t)
        }
    }
}
