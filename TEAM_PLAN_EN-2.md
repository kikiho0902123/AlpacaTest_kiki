# TEAM_PLAN v2 — Engineering Plan & Architecture Spec

Build with AI Hackathon | 2026/8/15 (Sat) | Three engineers: A (architecture + task flow), B (achievement + My Home track), C (AI track)
Source of truth: the "(New) Screen Inventory" master document. IDs like `TOD-01`, `SPL-01` refer to that document.

> How to read: everyone reads "0. Scope Decisions" and "1. Shared Contracts", then only your own section.
> The design document is the full product spec; this plan is the **10-hour hackathon execution subset**. "Batch 3 / cut" means not built today — not removed from the product.
>
> **Note for Claude Code**: this document is the target architecture. If the existing codebase deviates from it, refactor toward this spec — file layout, ownership boundaries, model definitions, the `AIService` interface, and the `RewardEngine` rules are all normative. UI copy shown to users stays in Traditional Chinese; keep existing Chinese strings.

---

## 0. Scope Decisions (whole team reviews before start; objections now, not at noon)

### In scope for the day (P0-Hackathon)

| Spec ID | Content | Owner |
|---|---|---|
| TOD-01/03 | Today Main + Action Task Card (To-do / Split / Done groups) | A |
| TOD-04 | "Start task — is it big? Split?" modal | A |
| TOD-05/06 | Completion confirm + completion note | B |
| TOD-07 | Task Record bottom sheet | C |
| TSK-01~04 | Create/Edit task (shared editor, 3 date states, inline category/subcategory creation) | A |
| TSK-06 | Delete confirm | A |
| STK-01~05 | Full stuck-help flow (8 rounds, chips, exit confirm, AI summary, not-helpful feedback) | C |
| SPL-01~06 | Full split flow (3 entry points, editable subtasks, confirm, done, read-only parent) | C |
| EOD-01/02/04/05/06 | Notification island, achievement modal, harvest animation, harvest done, day rollover | B |
| HOME-01/04/05/06 + C01~C03 | **My Home: wool bank, textile library, crafting area, 3 crafting modals** | B |
| FBK-01~05 (simplified) | Feedback Main + daily feedback (this week only, backed by seed data) | B |
| STATE-01~09 | All cross-screen state rules (see contracts) | All |

### Batch 3 (only if ahead of schedule; default = not built)

Onboarding (ONB-01~04) | Library by-category / by-time (all LIB-C, LIB-T) | all drag interactions | share templates (EOD-03/FBK-09) | weekly AI feedback text (FBK-07) | six-month history (FBK-08) | account/notification settings (HOME-02/03) | 05:00 auto rollover (EOD-02B/08)

### Explicitly not built today (talked through in the demo, or faked with data)

Real auth (Apple/Google Sign-In) | push notifications (the island is an in-app component) | Lottie/SpriteKit (static images + `withAnimation` only) | voice input

### Demo framing

"Library, Onboarding, and weekly analysis are fully designed (show one design page); today we focused on the core loop." Judges accept this framing — it reads as good judgment, not missing work.

---

## 1. Shared Contracts

> Contracts = the boundaries between the three engineers' code. Changing one requires all three to agree, is executed by A, and is announced immediately.

### 1. App structure (four tabs)

```
TabView
├─ Tab 1 "Today"  TodayView                            A
│   ├─ modal: DatePickerModal (TOD-02, today+future)    A
│   ├─ fullScreen: TaskEditorView (TSK-01/05 shared)    A
│   ├─ modal: StartAskSplitModal (TOD-04)               A
│   ├─ modal: CompleteConfirmModal (TOD-05)             B
│   ├─ modal: CompletionView (TOD-06)                   B
│   ├─ sheet: TaskRecordSheet (TOD-07)                  C
│   ├─ modal: StuckConfirmModal (STK-01)                C
│   ├─ fullScreen: StuckChatView (STK-02)               C
│   ├─ modal: SplitFlowModal (SPL-01~04)                C
│   └─ modal: EODAchievementModal → harvest → rollover  B
├─ Tab 2 "Library"  LibraryView                         A (Batch 3; WIP placeholder)
├─ Tab 3 "Feedback"  FeedbackView (FBK-01)              B
│   └─ push: DailyFeedbackView (FBK-03)                 B
└─ Tab 4 "My Home"  MyHomeView (HOME-01)                B
    └─ modal: CraftConfirm/Success/Insufficient         B
```

### 2. File structure & ownership (only edit files you own)

```
BuildWithAI/
├── BuildWithAIApp.swift              A   ModelContainer, 4-tab shell
├── Models/Models.swift               A   All @Model classes
├── Services/
│   ├── AIService.swift               C
│   ├── PromptBuilder.swift           C   includes 8-round behavior directives
│   ├── ScoringEngine.swift           C
│   ├── SeedData.swift                C
│   └── RewardEngine.swift            B   wool reward rules (sole entry point)
├── Views/
│   ├── Today/
│   │   ├── TodayView.swift           A
│   │   ├── TaskCardView.swift        A   Action variant
│   │   ├── AlpacaStatusView.swift    A   ★ alpaca only — no numbers, no caption (STATE-09)
│   │   └── StartAskSplitModal.swift  A
│   ├── Task/
│   │   ├── TaskEditorView.swift      A   Create/Edit shared (COM-04)
│   │   └── DatePickerModal.swift     A
│   ├── Chat/
│   │   ├── StuckChatView.swift       C
│   │   ├── ChatComponents.swift      C   bubbles, quick chips
│   │   ├── SplitFlowModal.swift      C
│   │   └── TaskRecordSheet.swift     C
│   ├── Feedback/
│   │   ├── FeedbackView.swift        B
│   │   ├── DailyFeedbackView.swift   B
│   │   ├── CompletionView.swift      B   includes TOD-05 confirm
│   │   └── EODFlow.swift             B   island, achievement, harvest, rollover
│   └── Home/
│       └── MyHomeView.swift          B   includes the 3 crafting modals
├── Components/
│   ├── Theme.swift                   A   colors, type scale, modal template (COM-06)
│   └── SharedComponents.swift        A   progress bar, complexity battery, tag chip
└── Resources/alpaca_0~3.png, textile_*.png
```

### 3. Data models (A pushes by 9:30 — the only blocking dependency)

```swift
import SwiftData
import Foundation

@Model
final class TodoTask {
    var id: UUID = UUID()
    var name: String
    var category: String?
    var subcategory: String?
    var colorHex: String?
    // Three date states (TSK-02): startDate set = scheduled;
    // nil + isUrgent = unscheduled-urgent; nil + !isUrgent = unscheduled-not-urgent
    var startDate: Date?
    var isUrgent: Bool = false
    var isMustToday: Bool = false
    var complexity: Int = 1              // 0 easy / 1 medium / 2 hard
    var note: String?
    var status: String = "notStarted"    // notStarted/started/split/done/archived
    var progress: Double = 0             // start → auto 0.2; 1.0 triggers completion flow (COM-02)
    var createdAt: Date = Date()
    var parentID: UUID?
    var sortOrder: Int = 0
    init(name: String) { self.name = name }
}

@Model
final class TaskLog {                    // STATE-08: start note / chat summary / completion note
    var id: UUID = UUID()
    var taskID: UUID
    var timestamp: Date = Date()
    var type: String                     // "startNote"/"chatSummary"/"completion"/"split"
    var content: String
    init(taskID: UUID, type: String, content: String) {
        self.taskID = taskID; self.type = type; self.content = content
    }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var taskID: UUID
    var sessionID: UUID                  // one stuck-help conversation = one session (round counting)
    var role: String                     // "user"/"assistant"
    var content: String
    var timestamp: Date = Date()
    init(taskID: UUID, sessionID: UUID, role: String, content: String) {
        self.taskID = taskID; self.sessionID = sessionID; self.role = role; self.content = content
    }
}

@Model
final class DailyStat {                  // one "subjective workday" (STATE-03)
    var date: Date                       // workday label
    var woolG: Int = 0                   // ★ grams. Accrues silently in the background (STATE-09)
    var startCount: Int = 0
    var stuckCount: Int = 0
    var doneCount: Int = 0
    var isClosed: Bool = false           // day ended (snapshot, STATE-04)
    var harvested: Bool = false
    init(date: Date) { self.date = date }
}

@Model
final class UserProfile {                // singleton. Onboarding not built; seeded with fake data
    var name: String = "Demo User"
    var woolBankG: Int = 0               // My Home wool bank (STATE-05)
    var gloveCount: Int = 0              // textile library (STATE-06)
    var scarfCount: Int = 0
    var capeCount: Int = 0
    var onboardingJSON: String = "{}"    // questionnaire answers; seeded fake, fed to prompts
    init() {}
}
```

Rules: new field → ask A. Status strings verbatim; do not invent values.

### 4. RewardEngine (owned by B; A/C only call it — never add wool yourselves)

```swift
enum RewardEngine {
    // Spec fixes only 15g per subtask start (SPL-06); the rest are provisional, tunable pre-demo
    static func woolFor(_ event: RewardEvent) -> Int {
        switch event {
        case .startTask: 50
        case .startSubtask: 15          // fixed by spec
        case .acceptSplit: 30
        case .stuckChatDone: 40
        case .complete(let cx): [100, 200, 300][cx]   // easy/medium/hard
        case .completionNoteBonus: 50   // TOD-06: extra reward when a note is written
        }
    }
    /// Sole entry point: adds to today's DailyStat.woolG and posts .woolGained (alpaca fluff animation)
    static func grant(_ event: RewardEvent, context: ModelContext)
}
```

**STATE-09 display rules (iron law, everyone):**
- Today view: **no gram counts, no captions anywhere** — only the alpaca getting fluffier
- Feedback Main: live alpaca + current accumulated grams + caption
- Achievement / harvest: the day's final gram count (first reveal)
- My Home: only harvested, banked grams

### 5. AIService interface (C pushes a stub with mock by 9:30)

```swift
struct StuckReply {
    var text: String                     // AI message
    var quickOptions: [String]           // light options ("close" / "partly" / …)
    var recommendSplit: Bool             // STK-02F: true only when conditions are met
    var isClosing: Bool                  // Round 5+ closure tone
}

final class AIService {
    static let shared = AIService()
    var useMock = true                   // stays true until real API works; also the offline demo mode

    /// Stuck-help chat. `round` computed by the caller (user messages in the session).
    /// Round 8: the caller disables input (STK-02H); safety triggers are exempt from the 8-round cap.
    func stuckChat(task: TodoTask, round: Int,
                   messages: [ChatMessage],
                   history: [HistoricalTaskSummary],
                   profileJSON: String) async throws -> StuckReply

    /// Split suggestion: 2–5 subtask names (SPL-01)
    func suggestSplit(task: TodoTask, chatContext: [ChatMessage]?) async throws -> [String]

    /// Non-editable summary on exit (STK-04)
    func summarize(messages: [ChatMessage]) async throws -> String
}

struct HistoricalTaskSummary: Codable {
    var name: String; var category: String?
    var daysAgo: Int; var hadStuckHelp: Bool
    var completionNote: String?; var score: Int
}
```

A and B touch AI only through this interface. Keys live in `Secrets.swift` (gitignored); repo ships `Secrets.example.swift`.

### 6. Cross-screen events

```swift
extension Notification.Name {
    static let woolGained    = Notification.Name("woolGained")    // A listens: alpaca fluff animation (COM-08)
    static let taskCompleted = Notification.Name("taskCompleted") // B listens: completion flow
    static let taskSplit     = Notification.Name("taskSplit")     // A listens: home refresh insurance
    static let dayEnded      = Notification.Name("dayEnded")      // B listens: EOD flow
}
```

### 7. Theme + modal template (COM-06)

A's first commit provides `Theme` and a unified `ConfirmModal(title:message:primary:secondary:)`.
The app's dozen-plus confirm/success/failure modals (TOD-04/05, STK-01/03, SPL-03/04, TSK-06, HOME-04/05/06, EOD-06) **all use this one template with different copy**. No bespoke modals.

---

## 2. Timeline

| Time | Event |
|---|---|
| 09:00 | A creates project (blue synchronized folders) + Theme + ConfirmModal template, push; B/C clone |
| **09:30** | **A pushes Models; C pushes AIService stub (mock); B pushes RewardEngine** → three tracks in parallel |
| 12:30 | Everyone finishes Batch 1 |
| **13:00** | **Integration checkpoint 1 (all stop, 20 min)**: demo main loop walks end-to-end |
| 13:20 | Scope Batch 2 based on measured velocity |
| **16:30** | **Integration checkpoint 2**; pitch team fully on |
| 17:00 | Mentor room closes |
| **18:00** | **Feature freeze** — bug fixes only |
| 19:00 | Demo rehearsal ×3 (wiped simulator + seed) |
| Before leaving | push / save recordings / verify no secrets |

Checkpoint 1 acceptance: home shows seeded cards → start a task, get asked "split?" → split flow creates subtasks → start a subtask, alpaca fluffs (no numbers) → another task: stuck chat (mock OK) → complete a task, write note → end day → achievement reveals grams → harvest → My Home shows banked wool. Zero crashes.

---

## 3. Engineer A — Architecture + Task Flow

### 09:00–09:30
1. Project (iOS 18 / SwiftUI / blue folders), `.gitignore` (incl. Secrets.swift), `Secrets.example.swift`
2. `Theme.swift` + `ConfirmModal` template + `SharedComponents` (progress, battery, chip shells)
3. `Models.swift` — implement the contract verbatim
4. `BuildWithAIApp.swift`: ModelContainer + 4 tabs (Tab 2 = WIP)
5. Push → everyone pulls

### Batch 1 (→12:30)
- `TodayView` (TOD-01): date/weekday heading, calendar icon, `AlpacaStatusView`, three groups (To-do / Split / Done), floating "+"
  - **Alpaca area shows the image only — no numbers, no caption.** Listens to `.woolGained` and plays an image-swap animation (fluff tier = today's woolG bucket; the mapping exists in code only, never on screen)
  - "End the day" notification island (EOD-01): always visible in dev for now; tap posts `.dayEnded`
- `TaskCardView` (TOD-03, Action variant):
  - Name, category color, subcategory, must-today, battery, progress (draggable; **auto 0.2 on start**; reaching 1.0 → post `.taskCompleted`)
  - "Start" → `StartAskSplitModal` (TOD-04): "No" → status=started, progress=0.2, `RewardEngine.grant(.startTask)` (use `.startSubtask` when parentID != nil), button becomes "Split"; "Yes" → C's `SplitFlowModal(source: .startAsk)`
  - "Split" (after started) → `SplitFlowModal(source: .manual)`
  - "Stuck" → `StuckConfirmModal` (C)
  - "Complete" → post `.taskCompleted` (B takes over)
  - "…": Edit → TaskEditor; Delete → ConfirmModal (TSK-06); View record → `TaskRecordSheet` (C)
  - **Split-parent variant (SPL-05)**: greyed out, no action buttons, record viewing only
- `TaskEditorView` minimal (name + 3-state date + must-today + battery — just enough to create tasks)

### Batch 2 (→16:30)
- Full `TaskEditorView` (TSK-01~05): category/subcategory pickers with inline creation (tap "+ add" → row becomes a text input → done), context note, edit mode pre-fills, CTA copy per mode
- `DatePickerModal` (TOD-02): today and future only; past disabled
- Home drag-to-reorder (`.onMove`)

### Batch 3
- `LibraryView` by-category (grid → category page → subcategory sections); by-time (calendar + unscheduled zones). **No dragging** — "… → assign date" menu instead
- Onboarding shell (welcome + fake login button + done page; questionnaire skipped)

### Integration duties
You run both checkpoints; packages/project settings are yours alone; you resolve pbxproj conflicts.

---

## 4. Engineer B — Achievement + My Home Track

Your track is the demo's reward feel at the start and the payoff at the end. The entire wool economy lives with you.

### 09:00–09:30
- Push `RewardEngine.swift` (contract version; `grant` writes DailyStat + posts the notification)
- Chase assets: `alpaca_0~3.png` + three textiles (gloves/scarf/cape; SF Symbols as placeholders if missing)

### Batch 1 (→12:30)
- `CompletionView.swift`:
  - TOD-05 confirm (shared template) → TOD-06 completion note (input + "Done" / "Skip")
  - On complete: TaskLog(completion), status=done, `grant(.complete(cx))`; if a note was written also `grant(.completionNoteBonus)` (spec: feedback earns extra background reward)
  - Entered via `.taskCompleted`
- `EODFlow.swift`:
  - `EODAchievementModal` (EOD-02A): day's alpaca, **the day's final grams revealed here for the first time**, biggest task of the day (highest woolG contributor), action tally (started ×N | stuck-help ×N | completed ×N), "Harvest" / "Cancel", share button (fake in Batch 1)
  - Harvest (EOD-04/05): `withAnimation` alpaca 3→0 image swap (~2 s) → "N g stored in the wool bank" → DailyStat.harvested, isClosed; `UserProfile.woolBankG += N` (STATE-05)
  - `EOD-06` rollover modal → create tomorrow's DailyStat, back to home
- **`MyHomeView.swift` (HOME-01)**:
  - Wool bank (woolBankG), textile library (three counts, empty-state copy), crafting area (gloves 600g / scarf 1,400g / cape 2,800g)
  - Tap a textile → `HOME-04` confirm (shared template) → enough: deduct + count+1 → `HOME-05` success; not enough → `HOME-06` insufficient. **Deduction and addition must be one transaction (STATE-06)**

### Batch 2 (→16:30)
- `FeedbackView` (FBK-01 simplified): live alpaca + **accumulated grams + caption (numbers are allowed on this screen)**, this week's 7 snapshot cells (past = tappable, today = in-progress disabled, future = "?") — past data comes from C's seed
- `DailyFeedbackView` (FBK-03/04/05): date, that day's alpaca snapshot, grams + caption, day's tasks (done → split → started → not-started), History Task Card (read-only progress + large Task Record area)
- Humorous caption constants (3 hardcoded rotating lines)

### Batch 3
- Share templates (EOD-03: full/simple, `ImageRenderer` to Photos)
- Weekly feedback text (via C's API)
- HOME-02/03 settings screens

---

## 5. Engineer C — AI Track

Unchanged principle: **mock → real API → smart**. The 8-round structure is implemented in the prompt, not as 8 screens.

### 09:00–09:30
- Push `AIService` stub + mock: `stuckChat` returns canned replies by round (round 1 → chips, round 3 → options, round ≥5 → `isClosing=true`), `suggestSplit` returns 3 fixed subtasks, `summarize` returns two sentences
- Push `Secrets.example.swift`

### Batch 1 (→12:30)
- **Real API integration**: `URLSession` async/await; back-off retry ×2 on 429/5xx (1s/3s); once working → `useMock=false`, tell everyone
- `PromptBuilder.swift`:
  - Base it on the designer's psychological-support prompt (Role / three-layer analysis / Output Guidelines)
  - **Inject round behavior**: system prompt carries `round` plus per-phase directives — R1 greeting + "what's blocking you"; R2 a 1–2-sentence working hypothesis + at most one high-information question; R3 understanding + insight + "give me a next step / keep talking"; R5–7 progressively converge, no new topics; R8 final understanding + single best next step + closure
  - Request JSON matching `StuckReply`; on parse failure, fall back to the whole text in `text`
  - `recommendSplit` criteria in the prompt (suggest only for step-confusion / oversized tasks — STK-02F "appears only when conditions are met")
- `StuckChatView.swift` (STK-02):
  - Entry gated by `StuckConfirmModal` (STK-01, shared template)
  - Round 1: AI greeting + **10 quick-response chips** (multi-select feeds the input; free text allowed; horizontal scroll when overflowing)
  - Bubble chat, light option buttons ("close / partly right / not quite / let me add")
  - `recommendSplit=true` → show "Split this task for me" / "Not yet, keep talking" (STK-02F)
  - **Round 8 input lock** (STK-02H): input disabled + "AI resting for 15 minutes" note; **safety flow is exempt**
  - Top-left exit → STK-03 confirm → "Leave & record" → `summarize` → STK-04 summary modal (non-editable) + "helpful / not helpful" → not helpful → STK-05 reason + input ("Done" / "Skip")
  - Summary → TaskLog(chatSummary); `grant(.stuckChatDone)`; if the chat ended via a split, the summary is written to the **parent task**
- `SplitFlowModal.swift` (SPL-01~04, shared by all three entries):
  - `source: .startAsk / .manual / .fromChat`
  - On appear call `suggestSplit` (`fromChat` passes chat context) → parent card + 2–5 subtask cards (indent + connector line — no fancy branch visuals)
  - Subtasks: rename / delete / add; full edit → open A's TaskEditor (COM-04 shared)
  - Confirm (SPL-03 template) → create subtasks (parentID, inherit category), parent status=split, `grant(.acceptSplit)`, post `.taskSplit` → SPL-04 done modal (**copy varies by source**: the plain-split variant must not mention "recording the chat")
- `ScoringEngine.swift`: per the formula (category 40/20, recency 30/20/10, quality 20+10, threshold ≥40, top 3–5, empty → cold start)
- `SeedData.swift` — **the soul of the demo**:
  - 5 historical tasks within 30 days (so the scoring engine selects 3) + 2 tasks for today + TaskLogs
  - **DailyStats for earlier days of this week (isClosed, harvested, varying woolG)** → gives B's feedback area content
  - UserProfile: fake onboarding JSON; woolBankG seeded at 500g (gloves cost 600g — completing tasks during the demo makes it *just* enough — **this is deliberate demo scripting**)
- `TaskRecordSheet.swift` (TOD-07): the task's TaskLog timeline as a bottom sheet

### Batch 2 (→16:30)
- **Safety layer (mandatory — judges will ask)**: keyword check before any API call (self-harm related) → on match do NOT call the API; show a fixed supportive message + **Taiwan 1925 crisis hotline**; exempt from the round-8 cap. System prompt: companion role, no diagnosis, no medical advice. One-line "not a medical service" disclaimer in About
- Prompt polish: feed profileJSON (fake questionnaire) so the opening line feels personalized
- Wire real scoring results into `stuckChat` context

### Batch 3
- Weekly feedback API (for B)
- Voice input

### Debugging
AI calls in the simulator only (Previews skip networking); print the raw response before parsing.

---

## 6. Demo Script v2 (three minutes)

1. Home: alpaca + today's tasks — note **no numbers anywhere on screen** (**A**) — say "rewards are felt, not calculated"
2. Start "Read Japanese for 3 hours" → asked "is this a big task?" → "Yes, split it" (**A→C**)
3. AI proposes 4 subtasks, rename one, confirm → back home: subtasks visible, parent moved to "Split" (**C→A**)
4. Start one subtask → alpaca gets slightly fluffier (**A**, no numbers)
5. Another task: "Stuck" → chat: AI's opener references last week's stuck record (**C** — seed data pays off) → two rounds → leave & record → summary (**C**)
6. Complete the subtask → one-line mood note (**B**)
7. "End the day" → achievement modal **reveals "1,240 g" for the first time** → harvest animation → banked (**B**)
8. Switch to My Home → wool bank now sufficient → **craft gloves → success** (**B**) ← the demo's ending
9. (Spoken) Library, onboarding, weekly analysis fully designed — one design page, move on

Pre-demo: Erase All Content → reinstall → seed auto-loads → walk the path once.

---

## 7. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Scope still too big | Checkpoint rule: Batch 1 not done by 13:00 → that track's Batch 2 is cut, hands to the main path. **Cut order: FBK area → SplitFlow editing (keep accept/reject only) → simplify 8 rounds to 4** |
| API key/credits arrive on the day | Mock is a complete offline demo mode; C proves the pipeline on personal quota beforehand, swaps the key on the day |
| AI JSON parse failure | Fallback into `text`; run the main path 5× pre-demo |
| 429 throttling | Retry built in; don't hammer during rehearsal |
| Wool numbers don't add up | Only RewardEngine adds wool; audit `grant` call sites |
| pbxproj conflicts | Synchronized folders + only A touches settings |
| Venue network dies | Hourly recordings + `useMock=true` |
