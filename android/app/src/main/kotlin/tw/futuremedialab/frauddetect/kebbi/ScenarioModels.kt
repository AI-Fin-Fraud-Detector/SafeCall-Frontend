package tw.futuremedialab.frauddetect.kebbi

// 動作腳本的資料結構。沒有語音欄位，語音由後端的 MP3 負責。

enum class ScenarioCategory {
    BUTLER,
    FRAUD_ALERT,
}

enum class LedPattern {
    OFF,
    BREATH_GOLD,      // 暖金，迎賓
    CYAN_FLOW,        // 青藍，引導
    PURPLE_PULSE,     // 紫，思考
    RAINBOW,          // 七彩輪播，歡慶
    SOFT_WHITE,       // 柔白，告別
    RED_STROBE,       // 紅光爆閃，阻攔
    RED_WHITE_ALERT,  // 紅白交替，驚慌
    SOLID_DARK_RED,   // 紅光恆亮，指責
    RED_AMBER_PULSE,  // 紅橙交替，駁斥
    POLICE_SIREN,     // 紅藍警笛，報警
}

enum class SoundType {
    TADA,
    ALARM_BUZZER,
    VERY_ALARMED,
    DING,
}

/** speed 為 m/s，正值前進。turnSpeed 為 deg/s，正值順時針。 */
data class ChassisMove(
    val speed: Float = 0f,
    val durationMs: Long = 0L,
    val turnSpeed: Float = 0f,
)

// ── 情緒動作與管家時機動作 (從 KebbiScenarioPlayer feat/sentiment-scenarios 移植) ──

/** 關節編號 (KebbiRemoteControl/docs/MOTOR_MAPPING.md)。 */
object Motor {
    const val NECK_Y = 1          // 頸部俯仰，正值低頭
    const val NECK_Z = 2          // 頸部左右，正值往機器人左邊
    const val R_SHOULDER_Z = 3    // 右肩前後，負值向前
    const val R_SHOULDER_Y = 4    // 右大臂抬舉，負值前抬
    const val R_SHOULDER_X = 5    // 右大臂側展，正值向外
    const val R_ELBOW = 6         // 右手肘，負值屈曲
    const val L_SHOULDER_Z = 7
    const val L_SHOULDER_Y = 8
    const val L_SHOULDER_X = 9
    const val L_ELBOW = 10
}

/** 直接控制一顆關節 (NuwaRobotAPI.ctlMotor)，送出前必須通過 [JointSafety]。 */
data class JointTarget(
    val motorId: Int,
    val degree: Float,
    val speed: Float = JointSafety.DEFAULT_SPEED,
)

/**
 * 關節安全白名單：KebbiRemoteControl B 實驗版 safe / caution 模式曾在實機執行的範圍，
 * 加上 KebbiScenarioPlayer 實機調整時確認過的值。這不是機械極限；超出範圍一律拒絕，不做截斷。
 */
object JointSafety {
    const val DEFAULT_SPEED = 90f
    const val MAX_SPEED = 200f

    val allowedRanges: Map<Int, ClosedFloatingPointRange<Float>> = mapOf(
        1 to -10f..25f,   // +20 以上超過 SDK 文件 ±20，實機調整確認可用
        2 to -40f..40f,
        3 to -120f..0f,
        4 to -180f..0f,
        5 to 0f..80f,
        6 to -120f..0f,
        7 to -120f..0f,
        8 to -180f..0f,
        9 to 0f..80f,
        10 to -120f..0f,
    )

    fun isAllowed(t: JointTarget): Boolean {
        val range = allowedRanges[t.motorId] ?: return false
        return t.degree in range && t.speed > 0f && t.speed <= MAX_SPEED
    }

    // 維持姿勢時的浮動：基準來自內建動作，所以用「相對幅度 + 速度 + SDK 文件範圍」檢查
    const val MAX_WIGGLE_AMPLITUDE = 15f
    const val MAX_WIGGLE_SPEED = 40f
    val sdkRanges: Map<Int, ClosedFloatingPointRange<Float>> = mapOf(
        1 to -20f..20f, 2 to -40f..40f, 3 to -85f..5f, 4 to -200f..70f, 5 to -3f..100f,
        6 to -80f..0f, 7 to -85f..5f, 8 to -200f..70f, 9 to -3f..100f, 10 to -80f..0f,
    )

    fun isWiggleAllowed(motorId: Int, base: Float, target: Float, speed: Float): Boolean {
        val range = sdkRanges[motorId] ?: return false
        return !base.isNaN() && kotlin.math.abs(target - base) <= MAX_WIGGLE_AMPLITUDE &&
            target in range && speed > 0f && speed <= MAX_WIGGLE_SPEED
    }
}

/**
 * 維持姿勢時的不規則浮動：以暫停當下的角度為基準，隨機挑 [minOffset, maxOffset] 內的目標，
 * 用 speed 移過去後隨機停留 minDwellMs~maxDwellMs，再重複。
 */
data class Wiggle(
    val motorId: Int,
    val minOffset: Float,
    val maxOffset: Float,
    val minDwellMs: Long,
    val maxDwellMs: Long,
    val speed: Float,
)

/** 整個劇本期間的表情 (臉部動畫名稱，只換臉，不帶表情包的配套身體動作)。 */
data class FaceCue(val name: String)

data class ScenarioStep(
    val name: String,
    val motionName: String? = null,
    val chassisMove: ChassisMove? = null,
    val ledPattern: LedPattern = LedPattern.OFF,
    val soundType: SoundType? = null,
    val timeoutMs: Long = 6000L,
    /** 直接控制關節 (情緒動作) */
    val jointTargets: List<JointTarget> = emptyList(),
    /**
     * 內建動作播到 holdAtMs 時暫停，維持姿勢直到 next()，再繼續播完。
     * 此時 timeoutMs 是最長維持時間 (安全上限)。
     */
    val holdAtMs: Long? = null,
    /** next() 之後，動作播完回到立正需要的時間 */
    val afterReleaseMs: Long = 1000L,
    /** 維持姿勢時的浮動 */
    val holdWiggle: List<Wiggle> = emptyList(),
)

data class Scenario(
    val id: String,
    val title: String,
    val category: ScenarioCategory,
    val description: String,
    val steps: List<ScenarioStep>,
    val face: FaceCue? = null,
)
