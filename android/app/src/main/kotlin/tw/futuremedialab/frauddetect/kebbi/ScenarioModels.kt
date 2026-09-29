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

data class ScenarioStep(
    val name: String,
    val motionName: String? = null,
    val chassisMove: ChassisMove? = null,
    val ledPattern: LedPattern = LedPattern.OFF,
    val soundType: SoundType? = null,
    val timeoutMs: Long = 6000L,
)

data class Scenario(
    val id: String,
    val title: String,
    val category: ScenarioCategory,
    val description: String,
    val steps: List<ScenarioStep>,
)
