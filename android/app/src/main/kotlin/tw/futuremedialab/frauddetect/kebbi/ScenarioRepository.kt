package tw.futuremedialab.frauddetect.kebbi

// 動作名稱與參數照 KebbiScenarioPlayer 原樣搬，不要自己改。
object ScenarioRepository {

    private val butlerWelcome = Scenario(
        id = "butler_welcome",
        title = "Grand welcome",
        category = ScenarioCategory.BUTLER,
        description = "Steps forward at 0.28 m/s, bows 90 degrees, then opens both arms wide",
        steps = listOf(
            ScenarioStep(
                name = "Step briskly forward",
                chassisMove = ChassisMove(speed = 0.28f, durationMs = 700L),
                ledPattern = LedPattern.BREATH_GOLD,
                timeoutMs = 1800L,
            ),
            ScenarioStep(
                name = "Deep bow",
                motionName = "666_RE_Bow",
                ledPattern = LedPattern.BREATH_GOLD,
                timeoutMs = 3800L,
            ),
            ScenarioStep(
                name = "Open both arms wide",
                motionName = "888_ML_HandsSideUp2_13",
                ledPattern = LedPattern.BREATH_GOLD,
                timeoutMs = 3200L,
            ),
        ),
    )

    private val butlerGuide = Scenario(
        id = "butler_guide",
        title = "Guide the way",
        category = ScenarioCategory.BUTLER,
        description = "Turns 60 degrees at 130 deg/s, raises an Ultraman-style guiding pose, then points at the target",
        steps = listOf(
            ScenarioStep(
                name = "Turn and raise guiding arm",
                motionName = "666_PE_Ultraman",
                chassisMove = ChassisMove(turnSpeed = 130f, durationMs = 500L),
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = 3800L,
            ),
            ScenarioStep(
                name = "Point straight at the target",
                motionName = "888_ML_RPointLisa_24",
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = 3200L,
            ),
        ),
    )

    private val butlerThinking = Scenario(
        id = "butler_thinking",
        title = "Thinking it over",
        category = ScenarioCategory.BUTLER,
        description = "Looks around, rests a hand on its chin, then claps once when the answer lands",
        steps = listOf(
            ScenarioStep(
                name = "Look around and ponder",
                motionName = "888_ML_Thinking_08",
                chassisMove = ChassisMove(turnSpeed = 80f, durationMs = 300L),
                ledPattern = LedPattern.PURPLE_PULSE,
                timeoutMs = 4000L,
            ),
            ScenarioStep(
                name = "Clap — got it",
                motionName = "888_ML_ThinkingOh_13",
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = 2800L,
            ),
        ),
    )

    private val butlerCelebrate = Scenario(
        id = "butler_celebrate",
        title = "Celebrate",
        category = ScenarioCategory.BUTLER,
        description = "Ta-da fanfare, grand applause, Superman pose, then holds a hand out for a high five",
        steps = listOf(
            ScenarioStep(
                name = "Grand applause",
                motionName = "888_ML_Kingclap_20",
                chassisMove = ChassisMove(turnSpeed = 100f, durationMs = 400L),
                ledPattern = LedPattern.RAINBOW,
                soundType = SoundType.TADA,
                timeoutMs = 3200L,
            ),
            ScenarioStep(
                name = "Superman pose",
                motionName = "667_P4_Superman",
                ledPattern = LedPattern.RAINBOW,
                timeoutMs = 3500L,
            ),
            ScenarioStep(
                name = "Hold out for a high five",
                motionName = "888_ML_HiFive_19",
                ledPattern = LedPattern.RAINBOW,
                timeoutMs = 3200L,
            ),
        ),
    )

    private val butlerFarewell = Scenario(
        id = "butler_farewell",
        title = "Farewell",
        category = ScenarioCategory.BUTLER,
        description = "Waves goodbye with a raised arm while rolling back at 0.24 m/s to clear the way",
        steps = listOf(
            ScenarioStep(
                name = "Wave goodbye and roll back",
                motionName = "666_RE_TurnRBye",
                chassisMove = ChassisMove(speed = -0.24f, durationMs = 600L),
                ledPattern = LedPattern.SOFT_WHITE,
                timeoutMs = 3200L,
            ),
        ),
    )

    private val fraudPhysicalBlock = Scenario(
        id = "fraud_physical_block",
        title = "Block the way",
        category = ScenarioCategory.FRAUD_ALERT,
        description = "Charges forward at 0.30 m/s as a physical barrier, air-raid buzzer, fists up ready to fight",
        steps = listOf(
            ScenarioStep(
                name = "Charge forward and block",
                chassisMove = ChassisMove(speed = 0.30f, durationMs = 700L),
                ledPattern = LedPattern.RED_STROBE,
                soundType = SoundType.ALARM_BUZZER,
                timeoutMs = 1300L,
            ),
            ScenarioStep(
                name = "Fists up, fighting stance",
                motionName = "666_FI_Fight",
                ledPattern = LedPattern.RED_STROBE,
                timeoutMs = 3500L,
            ),
        ),
    )

    private val fraudPanic = Scenario(
        id = "fraud_panic",
        title = "Panic and retreat",
        category = ScenarioCategory.FRAUD_ALERT,
        description = "Backs away at 0.26 m/s with both hands on its head, urgent alarm, then shakes all over",
        steps = listOf(
            ScenarioStep(
                name = "Hands on head, retreat",
                motionName = "888_ML_Noooo_21",
                chassisMove = ChassisMove(speed = -0.26f, durationMs = 900L),
                ledPattern = LedPattern.RED_WHITE_ALERT,
                soundType = SoundType.VERY_ALARMED,
                timeoutMs = 3800L,
            ),
            ScenarioStep(
                name = "Tremble",
                motionName = "888_ML_VeryScared_02",
                ledPattern = LedPattern.RED_WHITE_ALERT,
                timeoutMs = 3200L,
            ),
        ),
    )

    private val fraudAccuse = Scenario(
        id = "fraud_accuse",
        title = "Stern accusation",
        category = ScenarioCategory.FRAUD_ALERT,
        description = "Leans in at 0.26 m/s with a strongman chest pose, then stabs a finger at the phone",
        steps = listOf(
            ScenarioStep(
                name = "Lean in, strongman pose",
                motionName = "666_PE_Hercules",
                chassisMove = ChassisMove(speed = 0.26f, durationMs = 400L),
                ledPattern = LedPattern.SOLID_DARK_RED,
                timeoutMs = 2800L,
            ),
            ScenarioStep(
                name = "Point hard at the phone",
                motionName = "888_ML_AngPoint_12",
                ledPattern = LedPattern.SOLID_DARK_RED,
                timeoutMs = 3200L,
            ),
        ),
    )

    private val fraudReject = Scenario(
        id = "fraud_reject",
        title = "Refuse outright",
        category = ScenarioCategory.FRAUD_ALERT,
        description = "Sweeps both arms across its chest in a hard no, then shakes its head violently",
        steps = listOf(
            ScenarioStep(
                name = "Arms crossed, hard no",
                motionName = "667_P4_Wong",
                chassisMove = ChassisMove(turnSpeed = 80f, durationMs = 400L),
                ledPattern = LedPattern.RED_AMBER_PULSE,
                timeoutMs = 4500L,
            ),
            ScenarioStep(
                name = "Shake head violently",
                motionName = "666_BA_Shakehead",
                ledPattern = LedPattern.RED_AMBER_PULSE,
                timeoutMs = 2500L,
            ),
        ),
    )

    private val fraudSiren = Scenario(
        id = "fraud_siren",
        title = "Siren and spin",
        category = ScenarioCategory.FRAUD_ALERT,
        description = "Spins 180 degrees at 150 deg/s drawing a sword, red/blue police strobe, then palms down to settle",
        steps = listOf(
            ScenarioStep(
                name = "Draw sword and spin",
                motionName = "666_FI_Draw",
                chassisMove = ChassisMove(turnSpeed = 150f, durationMs = 1200L),
                ledPattern = LedPattern.POLICE_SIREN,
                timeoutMs = 4000L,
            ),
            ScenarioStep(
                name = "Palms down, settle",
                motionName = "667_MG_HandsUp",
                ledPattern = LedPattern.POLICE_SIREN,
                timeoutMs = 3200L,
            ),
        ),
    )

    /** 全部動作跑一遍，用來確認硬體正常 */
    private val megaDemo = Scenario(
        id = "mega_demo_60s",
        title = "Full demo (60s)",
        category = ScenarioCategory.BUTLER,
        description = "Chains every butler and fraud move together — use this to check the hardware end to end",
        steps = butlerWelcome.steps +
            butlerGuide.steps +
            butlerCelebrate.steps +
            fraudPhysicalBlock.steps +
            fraudPanic.steps +
            fraudReject.steps +
            fraudSiren.steps +
            butlerFarewell.steps,
    )

    val allScenarios: List<Scenario> = listOf(
        butlerWelcome,
        butlerGuide,
        butlerThinking,
        butlerCelebrate,
        butlerFarewell,
        fraudPhysicalBlock,
        fraudPanic,
        fraudAccuse,
        fraudReject,
        fraudSiren,
    )

    fun findById(id: String): Scenario? {
        if (id.equals(megaDemo.id, ignoreCase = true) || id.equals("demo", ignoreCase = true)) {
            return megaDemo
        }
        return allScenarios.find { it.id.equals(id, ignoreCase = true) }
    }
}
