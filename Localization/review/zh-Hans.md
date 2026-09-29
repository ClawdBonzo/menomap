# zh-Hans: review

A careful, natural Simplified Chinese translation in a consistent 你 register, with clean full-width punctuation, correct spacing around Latin text and placeholders, and consistent glossary use (热浪, 潮热, 夜间盗汗, 夜间守护, 晚间打卡, 热力图, 规律, 热度月报, 健康 App) across UI, widgets, Watch, Siri phrases, PDF and store. Patient terms match standard Chinese public-health usage and suit SG/MY readers (潮热, 盗汗, 围绝经期, 绝经, 绝经后出血, 激素治疗 (HRT/MHT), 孕激素, 早发性卵巢功能不全). Every safety string is faithful and complete with hedges intact; the bleeding-after-menopause trap is handled correctly everywhere (绝经后出血, 连续 12 个月没有月经), never 更年期后. Wry lines (私人夏天, 凌晨三点俱乐部, 体内桑拿：已开启, 空调遥控器：归我管, 真会挑时间) are gentle and well localized. Apple terms were checked against Apple's current zh-CN support pages: 控制中心, 锁定屏幕, 操作按钮 and its 控制 action, 添加控制, 添加小组件, 实时活动, 专注模式 / 打开时, 快捷指令, 可用 App / 安装, 复杂功能, 数码表冠, 家人共享 and Apple 账户 are correct. Fixes: Lock Screen 自定 → 自定义, Apple Watch App name, 旋转数码表冠, the Combined HRT category, dose-status wording, breathing phase 屏气, a few calques, one emergency-line collocation, and store keywords.

Changed 18 of about 877 entries (2%).

| id | before | after | why |
|---|---|---|---|
| 33 | %lld%% 在夜间（晚 9 点至早 7 点） | 夜间（晚 9 点至早 7 点）占 %lld%% | Original "%lld%% 在夜间…" is a calqued fragment that reads unnaturally; natural stat phrasing is "夜间…占 X%". |
| 62 | 漏用一次，只是记录里的一条备注。不说教。 | 漏用一次药，只是记录里的一条备注。不说教。 | "漏用一次" has no object and is unclear on its own; added 药 so it reads as a missed dose. |
| 165 | 复方 | 雌孕激素联合 | Medication category "Combined" (combined HRT). 复方 alone just means 'compound preparation' and doesn't say what is combined; 雌孕激素联合 is the standard Chinese wording for combined estrogen + progestogen therapy. |
| 249 | 致医生 | 面向医生 | Link label to the clinicians' information page; 致医生 reads like the salutation of a letter ('Dear doctor'). 面向医生 = 'for clinicians', faithful. |
| 289 | 屏住 | 屏气 | Breathing phase next to 吸气/呼气; 屏住 is incomplete without 呼吸. 屏气 is the standard pairing (吸气 · 屏气 · 呼气). |
| 495 | 在 iPhone 上打开 Watch App。 | 在 iPhone 上打开 Apple Watch App。 | Apple's zh-CN documentation calls the iPhone app 'Apple Watch App' ("在 iPhone 上前往 Apple Watch App"). |
| 512 | 一次付费。支持家人共享。 | 一次性付费。支持家人共享。 | 一次付费 is stiff; 一次性付费 is the idiomatic term for a one-time purchase. 家人共享 is Apple's official term (kept). |
| 620 | 跳过的剂量 | 跳过的用药 | "跳过的剂量" reads as 'the skipped dosage amount'; the pattern title means skipped doses. |
| 688 | 已用 | 已用药 | Dose status button; 已用 alone ('used') is unclear out of context. 已用药 fits gels, patches and tablets alike and stays within max 12. |
| 689 | 今天已用 | 今天已用药 | Aligned with 688 已用药. |
| 718 | 这可能是紧急情况。请联系当地急救电话。MenoMap 无法评估这种情况。 | 这可能是紧急情况。请拨打当地急救电话。MenoMap 无法评估这种情况。 | 联系…电话 is an awkward collocation; 拨打当地急救电话 is the natural phrasing for 'contact your local emergency number' and matches id 717 (请拨打 %@). Meaning and all sentences unchanged. |
| 720 | 这次热浪已不存在。 | 找不到这次热浪的记录。 | 这次热浪已不存在 ('this surge no longer exists') is an odd calque; the entry was deleted or is missing. |
| 724 | 用药时间：%@。轻点以标记已用或已跳过。 | 用药时间：%@。轻点以标记为已用药或已跳过。 | Aligned with 688 已用药 / 619 已跳过; added 为. |
| 735 | 按住锁定屏幕，然后轻点“自定”。 | 按住锁定屏幕，然后轻点“自定义”。 | Apple's current zh-CN iPhone User Guide labels the Lock Screen button “自定义” ("按住锁定屏幕直到屏幕底部出现“自定义”按钮"), not 自定. |
| 747 | 转动数码表冠 | 旋转数码表冠 | Apple zh-CN docs say 旋转数码表冠 for turning the Digital Crown. |
| 774 | 起床 | 起床时间 | Paired with 119 就寝时间 in the Night Watch Times section; 起床 alone reads as the verb 'get up'. |
| 790 | 出现什么情况时，我应该打电话联系？ | 我应该留意哪些情况？出现什么情况时需要打电话联系你？ | Original dropped 'watch for' and the addressee; this is a question for the clinician (like the other VisitQuestions that address 你). |
| store.keywords | 围绝经期,绝经,夜间盗汗,激素治疗,hrt,荷尔蒙,症状追踪,睡眠,失眠,月经周期,女性健康,中年,情绪,潮红,雌激素 | 围绝经期,绝经,夜间盗汗,盗汗,激素治疗,激素替代疗法,hrt,荷尔蒙,症状追踪,睡眠,失眠,月经周期,女性健康,情绪,潮红,雌激素,心悸,妇科 | Added 激素替代疗法 (how HRT is commonly searched in SG/MY), 盗汗, 心悸 and 妇科; dropped 中年, which users don't search and reads as unflattering. |

## Residual doubts

- 682: the Action Button 'Choose a Control' label (选取控制) could not be confirmed against a live zh-CN iOS device; Apple's guide confirms the action is named “控制” and the Control Center button “添加控制”. Kept.
- 729: Settings → Health → 数据访问与设备 follows Apple's usual zh-CN wording but was not checked on a device.
- The translation writes 健康 App without the quotes Apple's docs use (“健康” App); left as is because it is consistent throughout.
- 778: the Week tab is rendered 统计 (Stats); it describes the tab well and nothing refers to it by name, so kept.
