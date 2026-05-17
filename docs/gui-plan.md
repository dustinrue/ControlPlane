# ControlPlane — Final GUI Plan

This document captures the agreed design for the final ControlPlane GUI. It is a living
reference — update it as decisions are made during workshopping. Sections marked
**[OPEN]** still need decisions.

---

## 1. Menu Bar

### Current state
- Airplane SF Symbol icon on the left.
- Icon title updates to show active profile names (`" Home, Work"`).
- Menu contains: header, separator, Preferences…, Run Action flyout, separator,
  active profile list (disabled labels), separator, Quit.

### Target state

**Add a Profiles flyout** (same pattern as the existing Run Action flyout):

```
ControlPlane
────────────
Settings…           ⌘,
────────────
Profiles ▶          ← NEW flyout
  ○  Home           ← all profiles, inactive = hollow dot
  ●  Work           ← active (rule-engine) = filled dot
  🔒 VPN Override   ← manually locked = lock icon
Run Action ▶
────────────
● Work              ← active profiles summary (unchanged)
────────────
Quit ControlPlane   ⌘Q
```

**Manual override / "sticky" profiles**

Selecting a profile from the Profiles flyout manually activates it and marks it
**locked** until the user explicitly deactivates it. This implements Issue #521.

Rules:
- A locked profile stays active regardless of what the rule engine determines.
- The rule engine continues running normally; its results still govern
  non-locked profiles.
- A locked profile is shown with a lock icon (🔒) in the flyout.
- Clicking a locked profile in the flyout **removes the lock** and hands
  control back to the rule engine (which may immediately deactivate it).
- If the rule engine independently activates a profile that is also locked,
  that is fine — it remains active from both sources.
- Multiple profiles can be locked simultaneously.

**Implementation notes**
- `ProfileActivationManager` needs a `lockedProfiles: Set<UUID>` concept.
  Locked profiles are always included in the active set, merged with
  rule-engine results before callbacks fire.
- `AppDelegate` routes the flyout item click to
  `profileActivationManager.toggleLock(profileID:)`.
- The flyout item for each profile shows:
  - Current rule-engine active state (dot)
  - Locked state (lock icon, appended or replacing dot)
  - Profile name

**[OPEN]** Does locking a profile persist across app restarts, or is it
session-only? Suggested: session-only by default, with a "Keep locked after
restart" checkbox accessible via right-click on the locked item in the flyout.

---

## 2. Settings Window — Overall Structure

Rename "Preferences" → "Settings" (follows Apple HIG; tracked in Issue #540).

### Tab order (Profiles is the default/first tab)

| # | Tab | SF Symbol | Notes |
|---|-----|-----------|-------|
| 1 | **Profiles** | `person.2` | Default tab. Profile list + rule configuration. |
| 2 | **Actions** | `bolt` | Global action library (new architecture). |
| 3 | **Sensors** | `waveform` | Existing sensor config tab (unchanged). |
| 4 | **General** | `gear` | App-level settings: logging level (#543), launch at login, etc. |

---

## 3. Profiles Tab

### Layout

Three-panel horizontal split view:

```
┌──────────────┬────────────────────────┬──────────────────────┐
│ Profile list │  Profile detail        │  Rules for profile   │
│              │  (name, threshold,     │                      │
│ ○ Home       │   confidence badge)    │  [match] Rule name   │
│ ● Work  ←sel │                        │  [match] Rule name   │
│ ○ Weekend    │                        │  [match] Rule name   │
│              │                        │  …                   │
│ [+] [−]      │  Actions assigned:     │                      │
│              │  • Open Safari (act.)  │                      │
│              │  • Run Script  (deact) │  [+] [−] [✏]        │
└──────────────┴────────────────────────┴──────────────────────┘
```

**Panel 1 — Profile list (left, ~200 px)**
- Each row: active/inactive dot + profile name + current confidence score
  (shown as `0.84 / 1.00` using the live `profileConfidences` data — same as
  the current sidebar).
- Locked profiles get an additional 🔒 indicator.
- `[+]` / `[−]` toolbar buttons at the bottom.
- Right-click context menu: Rename, Delete, Duplicate **[OPEN]**.

**Panel 2 — Profile detail (centre, fixed ~280 px)**
- Editable name field (save on Return / focus-out).
- Confidence threshold slider (same as current).
- Exclusive toggle.
- Live confidence badge: `0.84 / 1.00` coloured green/orange/grey.
- **Assigned actions list** — a compact, read-only list of actions linked to
  this profile, showing action display name + trigger (on activate /
  on deactivate). Each row has a small `×` to remove the link.
  An `[+ Add Action]` button opens a sheet to link an action from the global
  library (see §4).

**Panel 3 — Rules (right, fills remaining space)**
- Identical to the current `RulesListView` including the live match-state
  column and the `[+]` / `[−]` / `[✏]` toolbar.
- No inner tabs — rules live directly in this panel.

**[OPEN]** Should the three-panel split be resizable or should panel 2 have a
fixed width? Suggested: panel 1 and 2 fixed, panel 3 fills.

**[OPEN]** Where does the "Duplicate profile" feature live? Useful for creating
a variant of an existing profile. Right-click context menu is the natural place.

---

## 4. Actions Tab (New Architecture)

### Motivation

Currently `ProfileAction` is always tied to a specific profile via `profileID`.
This means the same logical action (e.g., "connect to VPN") must be created
separately for every profile that needs it. The new architecture separates
action *definitions* from profile *assignments*:

- **`Action`** — a named, reusable action: type + configuration, no profile
  affiliation.
- **`ProfileActionLink`** — joins a profile to an action: `profileID`,
  `actionID`, `trigger` (on activate / on deactivate), `enabled`.

A single `Action` record can be linked to many profiles with the same or
different triggers.

### Tab layout

```
┌─────────────────────────────────────────────────────────────┐
│  Actions                                                    │
├──────────────────────────────────────────────────────────────┤
│  Type          Name                   Used by               │
│  ──────────    ──────────────────     ──────────────────    │
│  Shell Script  Connect VPN            Work, Travel          │
│  Open URL      Open Dashboard         Home                  │
│  Speak         Say Good Morning       Home, Weekend         │
│  …                                                          │
│                                                             │
│ [+] [−] [✏]                                                 │
└─────────────────────────────────────────────────────────────┘
```

- Each row: action type icon, display name, comma-separated list of profiles
  it is assigned to.
- `[+]` opens `CreateActionView` (type picker + config form, no profile
  assignment here — that happens from the Profiles tab).
- `[−]` deletes the selected action; warns if it is linked to one or more
  profiles.
- `[✏]` / double-click edits the action definition.
- **[OPEN]** Whether a "Run now" button belongs here for testing actions
  manually (analogous to the existing "Run Action" menu flyout).

### Linking actions to profiles

From **Panel 2** of the Profiles tab, clicking `[+ Add Action]`:
1. Opens a sheet listing all actions in the global library.
2. User picks one (or creates a new one inline).
3. User specifies the trigger: **On Activate** or **On Deactivate**.
4. The link is saved as a `ProfileActionLink` record.

### Database migration

This requires a schema change:

```sql
-- New table: action definitions (no profile affiliation)
CREATE TABLE actions (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    actionPluginID  TEXT NOT NULL,
    config          TEXT NOT NULL DEFAULT '{}',   -- JSON
    enabled         INTEGER NOT NULL DEFAULT 1,
    createdAt       TEXT NOT NULL,
    updatedAt       TEXT NOT NULL
);

-- New table: profile ↔ action links (replaces profileActions)
CREATE TABLE profileActionLinks (
    id          TEXT PRIMARY KEY,
    profileID   TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    actionID    TEXT NOT NULL REFERENCES actions(id)  ON DELETE CASCADE,
    trigger     TEXT NOT NULL,   -- "onActivate" | "onDeactivate"
    enabled     INTEGER NOT NULL DEFAULT 1,
    createdAt   TEXT NOT NULL
);
```

The old `profileActions` table is dropped. No data migration is needed or desired.

**Decision: wipe on schema change, no migration.**
`AppDatabase` already sets `migrator.eraseDatabaseOnSchemaChange = true` in
`#if DEBUG` builds. Adding the new migrations will automatically drop and
recreate the entire database the next time the app launches. This is the correct
behaviour for a pre-release app with a single developer. When the app eventually
ships publicly, a proper migration path can be added at that time.

---

## 5. Sensors Tab

Unchanged from current implementation. Displays all loaded sensors, their current
snapshot readings, and per-sensor configuration (where applicable). Remains the
third tab.

---

## 6. General Tab (New)

Collects app-level settings currently scattered or missing:

| Setting | Default | Notes |
|---------|---------|-------|
| Launch at login | Off | Standard `SMAppService` / `LaunchAgent` |
| Logging level | Off | Issue #543 — Off / Info / Debug |
| Show in Dock while Settings open | Off | Issue #540 |
| Notification style | Banner | Profile activate/deactivate notifications |
| **[OPEN]** Check interval override | — | For sensors that poll |

---

## 7. Deferred / Out of Scope for Initial GUI

These items are tracked as separate issues and are **not** part of the initial
GUI implementation sprint:

| Feature | Issue |
|---------|-------|
| Time of Day calendar-style rule editor | #544 |
| USB device name picker | #545 |
| Wi-Fi network scan + picker | #546 |
| Running Application picker (done) | — |
| Power source dropdown (done) | — |
| Structured logging UI | #543 |
| Dock icon while Settings open | #540 |
| Host Availability ping replacement | #539 |
| Manual profile override (menu lock) | #521 (implemented in §1 above) |
| Auto-update | #522 |
| Code signing / notarization | #523 |

---

## 8. Open Questions Summary

1. Does locking a profile persist across restarts?
2. Should Panel 2 (profile detail) have a fixed width or be resizable?
3. Where does "Duplicate profile" live in the UI?
4. Does the Actions tab need a "Run now" test button?
5. ~~Migrate or wipe existing `profileActions` data on schema change?~~ **Decided: wipe. `eraseDatabaseOnSchemaChange = true` already handles this in DEBUG builds.**
6. Should the Sensors tab move to position 3, or stay where it is?
7. **[OPEN]** Should the window have a minimum size change to accommodate the
   three-panel Profiles layout? Current minimum is 700 × 450.
