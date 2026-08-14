# Project Notes / Incident Log

## 2026-08-14 - "Nothing works, just a walking character" (Remotes dropped)

### Symptom
Playtest showed no light bikes, no AI, no collision - only a normal walking character.

### Root cause
`default.project.json` was regenerated (by `update_fmt.py` / the format-fix scripts) and the
four RemoteEvents under `ReplicatedStorage` were silently dropped:
- `TurnEvent` (RemoteEvent)
- `StateUpdate` (UnreliableRemoteEvent)
- `DeathEvent` (RemoteEvent)
- `ReplicateTurn` (RemoteEvent)

Every script blocks on `ReplicatedStorage:WaitForChild(...)` for these:

| Script | Lines |
|--------|-------|
| src/server/GameStateManager.luau | 5-6 (StateUpdate, ReplicateTurn) |
| src/server/MatchManager.luau | 2 (DeathEvent) |
| src/server/LightbikeServer.luau | 12 (TurnEvent) |
| src/client/LightbikeController.luau | 18-19 (TurnEvent, DeathEvent) |
| src/client/EnemyInterpolation.luau | 4-5 (StateUpdate, ReplicateTurn) |

Because the remotes never exist, `GameStateManager.init()` never completes: no Heartbeat
loop, no bikes, no AI, no broadcasts. Result: default walking character.

### Fix applied
Restored all four remotes in `default.project.json`.

### Guardrails (to prevent recurrence)
1. `update_fmt.py` now includes all four remotes AND asserts they exist before writing,
   so a regeneration can no longer silently drop them.
2. Rule: **never let a generator/script rewrite `default.project.json` from scratch.**
   Edit the existing file's tree in place; regenerate only for trivial reformatting.
3. Before playtesting, sanity check the tree:
   `src/` glob for `WaitForChild("...")` names and confirm each exists in
   `default.project.json` under `ReplicatedStorage`.
4. If you see only a walking character on playtest, first check that the
   RemoteEvents are still in `default.project.json`.