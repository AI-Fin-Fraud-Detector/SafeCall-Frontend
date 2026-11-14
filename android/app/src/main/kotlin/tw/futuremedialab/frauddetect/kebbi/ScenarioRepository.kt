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

    // ==========================================
    // 管家情緒動作與互動時機動作
    // 從 KebbiScenarioPlayer (lovincent20031008) feat/sentiment-scenarios 87de752 移植，
    // 在 KebbiScenarioPlayer 實機調整過；要改請先在 KebbiScenarioPlayer 調好再同步過來。
    // ==========================================
    // ---- 可調參數 (2026-11-12 實機回饋) ----
    // 正面：側邊上下快速揮動 (側展關節 M5/M9)
    private const val SIDE_UP = 80f          // 側舉上緣；SDK 上限 100 不碰端點
    private const val SIDE_LOW = 20f         // 揮動下緣，不完全放下讓揮動連續
    private const val SIDE_SPEED = 200f
    private const val SIDE_ELBOW = -30f      // 手肘微彎較自然
    private const val SWING_MS = 600L
    // 中立：雙手說話手勢 (胸前高度、手掌輕擺)，頭微側；不舉高、不低頭、不點頭、不觸碰自己
    private const val TALK_ARM = -90f        // 雙大臂前抬到胸前高度
    private const val TALK_ELBOW = -60f      // 前臂向前
    private const val TALK_ELBOW_BEAT = -30f // 手掌輕擺的另一端
    private const val TALK_OPEN = 20f        // 雙臂微向外 (M9 已測 +20；右手 M5 +20 曾有幅度異常紀錄)
    private const val TALK_SPEED = 90f
    private const val TALK_HEAD = 15f        // 頭左右搖擺幅度 (M2：正=機器人左、負=右；已測 -15~+25)
    private const val HEAD_SWAY_SPEED = 60f  // 30° 擺幅 / 60 ≈ 0.5 秒，配合每拍 BEAT_MS
    private const val BEAT_MS = 500L
    // 負面：低頭 + 垂手 + 收肩 + 難過表情
    private const val SAD_HEAD = 25f         // 超過 SDK 文件 ±20；2026-11-12 實機調整確認可用 (正值＝低頭)
    private const val SAD_SHOULDER = -120f
    private const val SAD_SPEED = 60f
    /**
     * 表情 = 臉部「動畫」名稱 (只換臉，不帶表情包配套動作)；這台凱比的臉部角色是 007。
     * 2026-11-12 實機以 /face/anim 截圖確認：播一次會停住，/face/reset 後恢復預設臉。
     * (表情包 JSON 如 007_P4_RPSTie 會連帶 robotMotion 身體動作，所以不用 JSON 名稱)
     */
    private val SAD_FACE = FaceCue("007_S2_Sad74")      // 難過流淚
    private val HAPPY_FACE = FaceCue("007_J3_Happy61")  // 星星眼開心

    private fun sideArms(deg: Float) = listOf(
        JointTarget(Motor.R_SHOULDER_X, deg, SIDE_SPEED),
        JointTarget(Motor.L_SHOULDER_X, deg, SIDE_SPEED)
    )

    /** 正面：雙臂從側邊對稱快速上下揮動 (Dael C8 / Gao B4) */
    private val sentimentPositive: Scenario = Scenario(
        id = "butler_sentiment_positive",
        title = "S1. 正面回覆・雙臂側邊揮動 (Positive)",
        category = ScenarioCategory.BUTLER,
        description = "雙臂由側邊快速上下揮動 4 次後回位，無台詞",
        face = HAPPY_FACE,
        steps = listOf(
            ScenarioStep(
                name = "雙臂側舉・手肘微彎",
                jointTargets = listOf(
                    JointTarget(Motor.R_SHOULDER_Y, 0f, SIDE_SPEED),
                    JointTarget(Motor.L_SHOULDER_Y, 0f, SIDE_SPEED),
                    JointTarget(Motor.R_ELBOW, SIDE_ELBOW, SIDE_SPEED),
                    JointTarget(Motor.L_ELBOW, SIDE_ELBOW, SIDE_SPEED)
                ) + sideArms(SIDE_UP),
                ledPattern = LedPattern.BREATH_GOLD,
                timeoutMs = 700L
            ),
            ScenarioStep("揮下 1", jointTargets = sideArms(SIDE_LOW), ledPattern = LedPattern.BREATH_GOLD, timeoutMs = SWING_MS),
            ScenarioStep("揮上 2", jointTargets = sideArms(SIDE_UP), ledPattern = LedPattern.BREATH_GOLD, timeoutMs = SWING_MS),
            ScenarioStep("揮下 2", jointTargets = sideArms(SIDE_LOW), ledPattern = LedPattern.BREATH_GOLD, timeoutMs = SWING_MS),
            ScenarioStep("揮上 3", jointTargets = sideArms(SIDE_UP), ledPattern = LedPattern.BREATH_GOLD, timeoutMs = SWING_MS),
            ScenarioStep("揮下 3", jointTargets = sideArms(SIDE_LOW), ledPattern = LedPattern.BREATH_GOLD, timeoutMs = SWING_MS),
            ScenarioStep("揮上 4", jointTargets = sideArms(SIDE_UP), ledPattern = LedPattern.BREATH_GOLD, timeoutMs = SWING_MS),
            ScenarioStep(
                name = "回位",
                jointTargets = sideArms(0f) + listOf(
                    JointTarget(Motor.R_ELBOW, 0f, SIDE_SPEED),
                    JointTarget(Motor.L_ELBOW, 0f, SIDE_SPEED)
                ),
                ledPattern = LedPattern.BREATH_GOLD,
                timeoutMs = 700L
            )
        )
    )

    /** 雙手手掌同步輕擺，頭同時左右搖擺 */
    private fun talkBeat(elbow: Float, head: Float) = listOf(
        JointTarget(Motor.L_ELBOW, elbow, TALK_SPEED),
        JointTarget(Motor.R_ELBOW, elbow, TALK_SPEED),
        JointTarget(Motor.NECK_Z, head, HEAD_SWAY_SPEED)
    )

    /** 中立：說話手勢 (論文無直接證據；避開各情緒群集特徵，最接近 Dael C2 無獨特模式) */
    private val sentimentNeutral: Scenario = Scenario(
        id = "butler_sentiment_neutral",
        title = "S2. 中立回覆・說話手勢 (Neutral)",
        category = ScenarioCategory.BUTLER,
        description = "雙手抬到胸前、手掌同步輕擺兩下像在說明，頭同時左右搖擺，然後回位；維持預設臉",
        steps = listOf(
            ScenarioStep(
                name = "雙手抬到胸前・頭轉左",
                jointTargets = listOf(
                    JointTarget(Motor.L_SHOULDER_Y, TALK_ARM, TALK_SPEED),
                    JointTarget(Motor.L_ELBOW, TALK_ELBOW, TALK_SPEED),
                    JointTarget(Motor.L_SHOULDER_X, TALK_OPEN, TALK_SPEED),
                    JointTarget(Motor.R_SHOULDER_Y, TALK_ARM, TALK_SPEED),
                    JointTarget(Motor.R_ELBOW, TALK_ELBOW, TALK_SPEED),
                    JointTarget(Motor.R_SHOULDER_X, TALK_OPEN, TALK_SPEED),
                    JointTarget(Motor.NECK_Z, TALK_HEAD, 55f)
                ),
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = 1100L
            ),
            ScenarioStep("手掌擺 1", jointTargets = talkBeat(TALK_ELBOW_BEAT, -TALK_HEAD), ledPattern = LedPattern.CYAN_FLOW, timeoutMs = BEAT_MS),
            ScenarioStep("手掌回 1", jointTargets = talkBeat(TALK_ELBOW, TALK_HEAD), ledPattern = LedPattern.CYAN_FLOW, timeoutMs = BEAT_MS),
            ScenarioStep("手掌擺 2", jointTargets = talkBeat(TALK_ELBOW_BEAT, -TALK_HEAD), ledPattern = LedPattern.CYAN_FLOW, timeoutMs = BEAT_MS),
            ScenarioStep("手掌回 2", jointTargets = talkBeat(TALK_ELBOW, TALK_HEAD), ledPattern = LedPattern.CYAN_FLOW, timeoutMs = BEAT_MS),
            ScenarioStep(
                name = "回位",
                jointTargets = listOf(
                    JointTarget(Motor.L_SHOULDER_Y, 0f, TALK_SPEED),
                    JointTarget(Motor.L_ELBOW, 0f, TALK_SPEED),
                    JointTarget(Motor.L_SHOULDER_X, 0f, TALK_SPEED),
                    JointTarget(Motor.R_SHOULDER_Y, 0f, TALK_SPEED),
                    JointTarget(Motor.R_ELBOW, 0f, TALK_SPEED),
                    JointTarget(Motor.R_SHOULDER_X, 0f, TALK_SPEED),
                    JointTarget(Motor.NECK_Z, 0f, 55f)
                ),
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = 1100L
            )
        )
    )

    /** 負面：低頭 + 雙手下垂 + 雙肩向前併攏 + 難過表情 (Gao B11；低頭替代軀幹前彎) */
    private val sentimentNegative: Scenario = Scenario(
        id = "butler_sentiment_negative",
        title = "S3. 負面回覆・低頭垂手收肩 (Negative)",
        category = ScenarioCategory.BUTLER,
        description = "低頭、雙臂下垂、雙肩向前併攏並顯示難過表情，停留後回位；頸部回位有 4~5 秒兩段式延遲",
        face = SAD_FACE,
        steps = listOf(
            ScenarioStep(
                name = "低頭・垂手・雙肩前收・難過臉",
                jointTargets = listOf(
                    JointTarget(Motor.NECK_Y, SAD_HEAD, 40f),
                    JointTarget(Motor.R_SHOULDER_Y, 0f, SAD_SPEED),
                    JointTarget(Motor.L_SHOULDER_Y, 0f, SAD_SPEED),
                    JointTarget(Motor.R_ELBOW, 0f, SAD_SPEED),
                    JointTarget(Motor.L_ELBOW, 0f, SAD_SPEED),
                    JointTarget(Motor.R_SHOULDER_Z, SAD_SHOULDER, SAD_SPEED),
                    JointTarget(Motor.L_SHOULDER_Z, SAD_SHOULDER, SAD_SPEED)
                ),
                ledPattern = LedPattern.SOFT_WHITE,
                timeoutMs = 2000L
            ),
            ScenarioStep("停留", ledPattern = LedPattern.SOFT_WHITE, timeoutMs = 2000L),
            ScenarioStep(
                name = "回位",
                jointTargets = listOf(
                    JointTarget(Motor.NECK_Y, 0f, 40f),
                    JointTarget(Motor.R_SHOULDER_Z, 0f, SAD_SPEED),
                    JointTarget(Motor.L_SHOULDER_Z, 0f, SAD_SPEED)
                ),
                ledPattern = LedPattern.SOFT_WHITE,
                // 雙肩 120 / 60 = 2 秒回位 (最慢的關節)；原本 7 秒等頸部兩段式回位，
                // 造成身體停了表情還在。改成跟可見動作一致，表情同時恢復。
                timeoutMs = 2200L
            )
        )
    )

    // ==========================================
    // 🧠 管家互動時機動作 (以 Nuwa 內建動作為基礎，方式 A：只加維持姿勢/燈光/表情/串接，不改動作本身)
    // 內建動作長度以 /motion/info (motionPrepare) 實測
    // ==========================================
    private const val MAX_LOOP_MS = 30_000L   // 維持姿勢安全上限：沒有收到 next() 時最多維持 30 秒
    // 暫停點 (毫秒)：2026-11-12 以 /motion/trace 實測關節軌跡
    // Tinythink：0.3~1.0s 抬手過渡、1.1~1.5s 完整思考姿勢 (低頭、雙手到下巴)、1.6s 起回立正
    // Listen：0.4~1.0s 過渡、1.1~1.5s 完整聆聽姿勢 (低頭、頭側轉、右手到耳邊)、1.6s 起回立正
    private const val THINK_HOLD_AT_MS = 1450L
    private const val LISTEN_HOLD_AT_MS = 1450L

    /** 等回覆：Tinythink 播到思考姿勢就停住，回覆到達後播完；紫色脈衝燈 */
    private val butlerThinkLoop: Scenario = Scenario(
        id = "butler_think_loop",
        title = "T1. 等待回覆・思考維持 (Thinking Hold)",
        category = ScenarioCategory.BUTLER,
        description = "內建 888_ML_Tinythink_25 播到思考姿勢就停住，回覆到達 (next()) 後播完回到立正；紫色脈衝燈",
        steps = listOf(
            ScenarioStep(
                name = "思考 (維持到回覆到達)",
                motionName = "888_ML_Tinythink_25",
                holdAtMs = THINK_HOLD_AT_MS,
                afterReleaseMs = 800L,   // 內建動作 2.0 秒，暫停點後剩約 0.55 秒
                // 思考：頭不規則左右轉 (像在琢磨)、托腮的左手微調、右手肘偶爾動
                holdWiggle = listOf(
                    // 基準 (trace)：頭左右 ≈0、左大臂 ≈-104、右手肘 ≈-42
                    Wiggle(Motor.NECK_Z, -15f, 15f, 700L, 1800L, speed = 35f),
                    Wiggle(Motor.L_SHOULDER_Y, -15f, 15f, 900L, 2000L, speed = 30f),
                    Wiggle(Motor.R_ELBOW, -12f, 12f, 1000L, 2200L, speed = 30f)
                ),
                ledPattern = LedPattern.PURPLE_PULSE,
                timeoutMs = MAX_LOOP_MS
            )
        )
    )

    /** 長輩說話時：Listen 播到聆聽姿勢就停住，說完後播完並點頭表示聽到了 */
    private val butlerListenNod: Scenario = Scenario(
        id = "butler_listen_nod",
        title = "T2. 長輩說話・聆聽維持後點頭 (Listening Hold + Nod)",
        category = ScenarioCategory.BUTLER,
        description = "內建 666_DA_Listen 播到聆聽姿勢就停住，長輩說完 (next()) 後播完並接 666_BA_Nodhead 點頭；青藍燈",
        steps = listOf(
            ScenarioStep(
                name = "聆聽 (維持到長輩說完)",
                motionName = "666_DA_Listen",
                holdAtMs = LISTEN_HOLD_AT_MS,
                afterReleaseMs = 800L,   // 內建動作 1.96 秒，暫停點後剩約 0.5 秒
                // 聆聽：頭往說話者方向微調、耳邊的右手微動、偶爾點頭
                holdWiggle = listOf(
                    // 基準 (trace)：頭左右 ≈12.7、右大臂 ≈-86、頭俯仰 ≈15.6 (SDK 上限 20，所以點頭往上抬 8、往下只到 4)
                    Wiggle(Motor.NECK_Z, -12f, 12f, 1200L, 2500L, speed = 30f),
                    Wiggle(Motor.R_SHOULDER_Y, -15f, 15f, 1000L, 2200L, speed = 30f),
                    Wiggle(Motor.NECK_Y, -8f, 4f, 1500L, 3000L, speed = 30f)
                ),
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = MAX_LOOP_MS
            ),
            ScenarioStep(
                name = "點頭 (我聽到了)",
                motionName = "666_BA_Nodhead",
                ledPattern = LedPattern.CYAN_FLOW,
                timeoutMs = 1400L   // 內建動作 1.2 秒 (SafeCall 以計時進下一步)
            )
        )
    )

    /** 道別：J1_Bye (2.5s) + 開心表情 (與 Nuwa 的 J1_Bye 表情包同一個動畫) */
    private val butlerByeHappy: Scenario = Scenario(
        id = "butler_bye_happy",
        title = "T3. 道別・開心揮手 (Farewell)",
        category = ScenarioCategory.BUTLER,
        description = "內建 000_J1_Bye (2.5 秒) 揮手道別，配開心表情 007_J3_Happy61；暖金燈",
        face = HAPPY_FACE,
        steps = listOf(
            ScenarioStep(
                name = "揮手道別",
                motionName = "000_J1_Bye",
                ledPattern = LedPattern.BREATH_GOLD,
                timeoutMs = 2700L   // 內建動作 2.5 秒 (SafeCall 以計時結束)
            )
        )
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
        sentimentPositive,
        sentimentNeutral,
        sentimentNegative,
        butlerThinkLoop,
        butlerListenNod,
        butlerByeHappy,
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
