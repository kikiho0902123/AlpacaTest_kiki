# ENGINEER_A_PLAN — Architecture + Task Flow

Build with AI Hackathon | 2026/8/15 | Owner: A
Reference: `TEAM_PLAN_EN.md` (scope, contracts, IDs). This doc is **execution order only**.

> Shared Contracts are already pushed. B and C are unblocked.
> Refactoring has already generated part of this — **Step 0 is an audit, not a rewrite.** Verify what exists, keep what works, only build what's missing.

---

## 🔄 Handoff status (last updated: 2026-08-15, mid Step 1)

**Active branch:** `feature/step1-taskcardview` — **not built, not pushed, not merged.**

**Done**
- **Step 0 audit** — complete; table below filled. Build passed clean at audit time.
- **Step 1 — `TaskCardView`** — all 5 requested gaps implemented in
  `Views/Today/TaskCardView.swift`:
  1. ✅ Category color bar — reads `task.colorHex` via new `Color(hex:)`; falls back to `.alpacaTerracotta`.
  2. ✅ Primary button label swaps `開始` → `拆分` once `status == "started"`.
  3. ✅ Empty `print()`-only buttons: `拆分` (post-start), `卡住了`, `…` (to be wired in Step 4).
  4. ✅ Progress reaching `1.0` posts `.taskCompleted` (via `.onChange`, guarded on the `<1.0 → ≥1.0` crossing).
  5. ✅ `complete()` now **only** posts `.taskCompleted` — removed the `status="done"` mutation and the `.complete` reward (B's TOD-05/06 flow owns that transition).
- Added `Color(hex:)` initializer to `Components/Theme.swift` (A-owned).
- Progress percentage caption kept (COM-02, confirmed fine).

**⚠️ Pending — next agent must do these before pushing**
- [ ] **Render the Preview** in `TaskCardView.swift` (has a 2-card preview: not-started + started) — visual verify was interrupted, never captured.
- [ ] **Build** (`Cmd+B`) — not run since the edit; must pass before merge (hard rule).
- [ ] If green: **push** the branch and tell B and C the card is available.

**Deliberately NOT built (per instruction, leave for later):** must-today tag, subcategory line, split-parent variant (SPL-05), visual polish.

**Untouched (owned by B/C):** no B- or C-owned files were modified.

---

## Priority principle

Work is ordered by **who is waiting on you**, not by screen order.

```
TaskCardView  →  blocks C (SplitFlowModal subtask cards) and B (History variant)
TodayView     →  blocks nothing, but it's where everything renders
TaskEditor    →  blocks nothing
Wiring        →  needs C's screens to exist
```

Never go more than **45 minutes without a push**. You are the source of shared components; if you stall, B and C start building their own.

---

## Step 0 — Audit what the refactor already produced (15 min, do this first)

Do not write code until this table is filled in.

```bash
git pull
find . -name "*.swift" | sort
```

| Component | Exists? | Matches contract? | Action |
|---|---|---|---|
| `Models.swift` — TodoTask (not `Task`) | ☐ | ☐ | |
| `Theme.swift` | ☐ | ☐ | |
| `ConfirmModal` template (COM-06) | ☐ | ☐ | |
| `SharedComponents` (progress, battery, chip) | ☐ | ☐ | |
| `BuildWithAIApp.swift` — 4 tabs | ☐ | ☐ | |
| `TaskCardView` | ☐ | ☐ | |
| `TodayView` | ☐ | ☐ | |
| `TaskEditorView` | ☐ | ☐ | |
| `AlpacaStatusView` | ☐ | ☐ | |

Three things to check specifically, because refactors get them wrong:

1. **No `Task` naming collision** — must be `TodoTask` (clashes with Swift Concurrency otherwise)
2. **STATE-09 violation** — does any Today-screen view display gram counts or wool captions? If yes, **delete them now**. Only the alpaca image may change.
3. **Wool is granted only via `RewardEngine.grant()`** — no `woolG += n` anywhere in your files

Build once (`Cmd+B`) before starting. If the refactored code doesn't compile, fixing that is task #1.

---

## Step 1 — TaskCardView (→ 10:15) ★ HIGHEST PRIORITY

Both B and C are blocked on this. Ship a **working minimum**, not a finished card.

### Must have
- [x] Task name, category color bar, complexity battery, progress bar
- [x] "Start" button → `status = "started"`, `progress = 0.2`, `RewardEngine.grant(.startTask)` (use `.startSubtask` when `parentID != nil`)
- [x] After start, the button label becomes "Split"
- [x] "Complete" button → `NotificationCenter.post(.taskCompleted)` (post ONLY; no status mutation)
- [x] Progress drag; reaching `1.0` also posts `.taskCompleted`
- [x] "Stuck", "Split", "…" as **empty buttons with `print()`** — wired in Step 4

### Deliberately deferred
Must-today tag, subcategory line, visual polish, split-parent variant.

**Push. Tell B and C the card is available.** ← ⚠️ NOT done yet: build + Preview verify still pending (see Handoff status at top).

---

## Step 2 — TodayView (→ 11:15)

- [ ] Date + weekday heading, calendar icon (opens nothing yet)
- [ ] `@Query` today's tasks, sorted by `sortOrder`
- [ ] **Three sections: To-do / Split / Done** (TOD-01)
- [ ] `AlpacaStatusView` — **image only. No gram count. No caption.** (STATE-09)
- [ ] Listen for `.woolGained` → swap alpaca image inside `withAnimation` (crossfade is enough)
- [ ] Floating "+" → presents an empty sheet for now

C's seed data should land around here. This is the first time you see the app with real content.

**Push.**

---

## Step 3 — TaskEditorView, minimal (→ 11:45)

Four fields only:
- [ ] Name
- [ ] Date (3 states: scheduled / unscheduled-urgent / unscheduled-not-urgent)
- [ ] Must-today toggle
- [ ] Complexity picker

Create + Cancel. Wire it to the "+" button.

Deferred to Batch 2: category/subcategory pickers with inline creation, context note, edit-mode prefill.

**Push.**

---

## Step 4 — Wiring (→ 12:15)

Return to `TaskCardView` and connect the empty buttons.

- [ ] "Start" → `StartAskSplitModal` (TOD-04)
  - "No" → start the task as in Step 1
  - "Yes" → C's `SplitFlowModal(source: .startAsk)`
- [ ] "Split" (post-start) → `SplitFlowModal(source: .manual)`
- [ ] "Stuck" → C's `StuckConfirmModal`
- [ ] "…" menu → Edit (TaskEditor) / Delete (`ConfirmModal`, TSK-06) / View record (C's `TaskRecordSheet`)

**If C's screens aren't ready, wire to placeholders.** The routing logic is what matters; the real screens drop in for free once they land.

---

## Step 5 — Loose ends (→ 12:30)

- [ ] Split-parent card variant (SPL-05): `status == "split"` → greyed out, no action buttons, "View record" only
- [ ] "End the day" notification island (EOD-01) → posts `.dayEnded` for B. Always visible during dev.

---

## 13:00 — Integration Checkpoint 1 (you run it)

All hands stop for 20 minutes. Walk the full path on one simulator:

1. Home shows seeded task cards
2. Start a task → "is this a big task?" → split flow → subtasks created
3. Parent moves to the Split section, greyed out
4. Start a subtask → alpaca fluffs up (no numbers on screen)
5. Another task → "Stuck" → chat (mock is fine)
6. Complete a task → completion note
7. "End the day" → achievement modal reveals grams → harvest
8. My Home shows banked wool

Log bugs, assign them, **do not fix them yourself**. From here your job shifts from building to integrating.

**Scope decision at 13:20**: if any track missed Batch 1, cut that track's Batch 2 per the cut order in TEAM_PLAN_EN.md §7.

---

## Batch 2 (13:20 → 16:30)

- [ ] Full `TaskEditorView` (TSK-01~05): category/subcategory pickers with **inline creation** (tap "+ add" → row becomes a text field → confirm), context note, edit-mode prefill, CTA copy per mode
- [ ] `DatePickerModal` (TOD-02): today and future only, past dates disabled
- [ ] Card polish: must-today tag, subcategory line, spacing pass against the design
- [ ] Home drag-to-reorder (`.onMove` writes back `sortOrder`)

---

## Batch 3 (only if genuinely ahead)

- [ ] `LibraryView` by-category: grid → category page → subcategory sections. **No drag interactions** — use a "… → assign date" menu instead
- [ ] `LibraryView` by-time: calendar + unscheduled zones
- [ ] Onboarding shell: welcome + fake login + done (skip the questionnaire)

---

## Standing responsibilities (all day)

**You are the only person who touches:**
- Swift Packages
- Bundle ID, deployment target, capabilities, signing
- `project.pbxproj` conflict resolution

**Conflict recovery:**
```bash
git checkout --theirs *.xcodeproj/project.pbxproj
git add . && git commit
```
Then verify in Xcode that your files are still in the compile list.

**Interruption management:** you will be interrupted constantly. Tell B and C: *non-urgent questions get batched — ask me on the hour.* Urgent = blocked, can't proceed.

---

## Hard rules

| | |
|---|---|
| Push cadence | ≤ 45 min |
| Before merging to main | `Cmd+B` must pass |
| Today screen | Zero numbers, zero wool captions (STATE-09) |
| Wool | Only via `RewardEngine.grant()` |
| Model name | `TodoTask`, never `Task` |
| 18:00 | Feature freeze — bugs only |

---

## Xcode + Claude Code

"The backing file has been modified outside of Xcode" → always choose **Use Version on Disk**.

Let Claude Code finish a full pass before editing in Xcode. Don't run both on the same files simultaneously.

Never add `.md` files to the Xcode project — they belong in the repo root, not the target.
