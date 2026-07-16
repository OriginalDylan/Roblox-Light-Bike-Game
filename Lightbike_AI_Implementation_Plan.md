# Lightbike AI Implementation Plan

**Target file:** `server/AIBot.luau` (currently a stub)
**Goal:** Replace circle-driving behavior with an AI that survives, plays tactically, and is genuinely fun to compete against — at multiple difficulty levels.
**Constraints to respect:** server is authoritative at 30 Hz, all collision is math-based axis-aligned line intersection (no raycasts), turns are grid-snapped 90°, and the AI must go through the same validation path as a real player so it can't cheat or desync.


---

## 1. Design goals

- **Fair, not psychic.** The AI should only "see" what a player could infer from the same game state (all trail segments + positions are already server-authoritative, so this is really about *response quality*, not information — see difficulty tuning for how to make lower tiers feel more human/fallible).
- **Layered decision-making**, cheapest checks first:
  1. **Survival** — will I die in the next N studs? If yes, must turn.
  2. **Space awareness** — of the safe options, which one keeps me alive longer / avoids trapping myself?
  3. **Strategy** — can I use a safe move to cut off or pressure the player?
- **Cheap per-tick cost.** Full flood fill every tick at 30 Hz for multiple bots will get expensive — most of the plan below uses fast approximations and only drops to a real flood fill occasionally.
- **Goes through normal turn validation.** The AI shouldn't have a private "God mode" collision path — reuse `CollisionService`'s intersection functions so AI and player play by identical rules.

---

## 2. Data the AI needs each decision

Pull this from `GameState.luau` (already tracked server-side, no new replication needed):

- Own bike: grid position, current heading (N/E/S/W), speed, last turn tick.
- All other bikes' positions/headings (for player prediction + threat awareness).
- All active trail segments (own, player's, other bots') as line segments — this is exactly what `CollisionService` already consumes.
- Arena bounds (from `Constants.luau`).

No new data model is needed — the AI is just another consumer of state that already exists.

---

## 3. Core algorithm: layered decision pipeline

Run this on a fixed cadence, **not necessarily every server tick** (see Performance section). At a high level, each evaluation asks: *"of {continue straight, turn left, turn right}, which options are safe, and which safe option is best?"*

### Layer 1 — Survival check (every eligible tick)

For each of the 3 candidate directions (straight/left/right — u-turns are invalid by definition of 90° grid turns), project a line segment forward from the bike's current position out to `lookaheadStuds`. Use the *same* segment-intersection function `CollisionService` uses for player collision to test that projected segment against:

- All trail segments (own + everyone else's)
- Arena bounds

```lua
-- Pseudocode — reuse CollisionService's existing intersection test
local function isDirectionSafe(bike, direction, lookaheadStuds)
    local projectedSegment = Geometry.projectSegment(bike.position, direction, lookaheadStuds)
    return not CollisionService.segmentHitsAnything(projectedSegment, allTrailSegments, arenaBounds)
end
```

If **zero** directions are safe, the bot is dead no matter what — just pick straight (deterministic, no wasted compute).
If **one** is safe, take it immediately, skip Layers 2–3 (no decision to make).
If **multiple** are safe, proceed to Layer 2.

### Layer 2 — Space evaluation (only when there's a real choice)

Rather than a full flood fill every time (expensive), use a **ray-based open-space score** as the default, and reserve true flood fill for periodic deeper checks.

**Fast heuristic (default):** From the candidate position, cast short probes (reusing the same line-intersection function) in the 3 forward-facing directions relative to that heading, out to a capped distance (e.g. 2–3x `lookaheadStuds`). Score = sum (or min, for a more conservative bot) of the clear distances in each probe direction.

```lua
local function scoreDirection(bike, direction)
    local candidatePos = bike.position + Directions[direction] * moveStep
    local total = 0
    for _, probeDir in candidateProbeDirections(direction) do
        total += distanceToNearestObstacle(candidatePos, probeDir, maxProbeDistance)
    end
    return total
end
```

This is cheap (a handful of line intersection tests) and correctly avoids "obviously bad" choices like turning toward a wall 3 studs away vs. open space.

**Periodic deep check (higher difficulties only):** Every `floodFillInterval` ticks (e.g. every 10–15 ticks, not every tick), run a coarse flood fill on a downsampled grid (e.g. 32–64 stud cells instead of 1-stud precision) from each safe candidate direction, counting reachable free cells up to a budget (e.g. stop after 300 cells — you just need "is this a trap" resolution, not an exact count). This catches C-shaped dead ends and self-trap situations that ray probes miss, at a fraction of the cost of per-tick full flood fill.

```lua
local function quickFloodFillScore(startCell, freeCellGrid, cellBudget)
    local visited, queue, count = {}, {startCell}, 0
    while #queue > 0 and count < cellBudget do
        local cell = table.remove(queue)
        if not visited[cell] and freeCellGrid[cell] then
            visited[cell] = true
            count += 1
            for _, neighbor in neighborsOf(cell) do
                table.insert(queue, neighbor)
            end
        end
    end
    return count -- higher = safer/more open
end
```

Pick the safe direction with the highest score (fast heuristic normally, flood-fill score when it's been computed that tick).

### Layer 3 — Strategic behavior (medium/hard difficulty only)

Among directions that are safe *and* roughly similar in space score, prefer the one that also advances a tactic:

- **Cut-off / prediction:** Linearly extrapolate the player's position from their current heading + speed N ticks ahead. If a safe candidate direction moves the bot toward intercepting that projected path (without violating Layer 1 safety for the bot itself), weight it higher. Keep this simple — extrapolate current heading only; don't try to model the player's future turns, that reads as unfair/psychic.
- **Wall-hugging:** When trailing near the player's own trail or the AI's own recent trail, mildly prefer directions that stay close-parallel to a trail (uses the trail as a soft barrier and denies the player space) rather than drifting to open center — this is the classic Tron "closing off territory" tactic.
- **Aggression weight:** A tunable 0–1 value blends the "safe space score" and "strategic score" — low aggression = pure survival play, high aggression = will take slightly riskier lines to pressure the player.

This layer should only ever choose *among already-safe* options from Layer 1 — never override survival.

---

## 4. Suggested `AIBot.luau` structure

```lua
local AIBot = {}
AIBot.__index = AIBot

function AIBot.new(bikeId: string, difficulty: string)
    local self = setmetatable({}, AIBot)
    self.bikeId = bikeId
    self.profile = Constants.AI_DIFFICULTY[difficulty]
    self.lastDecisionTick = 0
    self.ticksSinceFloodFill = 0
    return self
end

-- Called from the server tick loop, same cadence as other authoritative updates.
-- Returns nil (no turn) or a TurnDirection to feed into the SAME validation
-- path used for player TurnEvents, so results are trustworthy and consistent.
function AIBot:Update(tick: number, gameState: GameState.State): Types.TurnDirection?
    local bike = gameState:GetBike(self.bikeId)
    if not self:shouldEvaluate(tick, bike) then
        return nil
    end

    local safeDirections = self:getSafeDirections(bike, gameState)
    if #safeDirections == 0 then
        return nil -- unavoidable, don't spend budget deciding
    end
    if #safeDirections == 1 then
        return safeDirections[1]
    end

    local useFloodFill = self.profile.floodFillEnabled
        and (self.ticksSinceFloodFill >= self.profile.floodFillInterval)

    local best = self:pickBest(bike, gameState, safeDirections, useFloodFill)
    if useFloodFill then
        self.ticksSinceFloodFill = 0
    else
        self.ticksSinceFloodFill += 1
    end

    return best
end

return AIBot
```

Key point: `AIBot:Update` should return an *intent*, and the server should validate/apply it through the exact same code path `TurnEvent` uses for players (min segment length, grid snap, etc.). Don't give the AI a shortcut that bypasses `CollisionService` — bugs there should affect the AI too, which keeps behavior consistent and makes testing easier.

---

## 5. Integration with the server tick

In `MatchManager.luau` (or wherever the 30 Hz loop lives in `LightbikeServer.luau`), after resolving player input for the tick:

```lua
for _, bot in activeBots do
    local turnIntent = bot:Update(currentTick, gameState)
    if turnIntent then
        LightbikeServer:ApplyValidatedTurn(bot.bikeId, turnIntent, currentTick)
        -- reuse whatever function processes a validated player TurnEvent
    end
end
```

`ApplyValidatedTurn` should be the shared function player turns already funnel into post-validation — this guarantees AI turns update `StateUpdate`/`ReplicateTurn` broadcasts identically to player turns, so clients don't need any special-case code for bots.

---

## 6. Difficulty tuning table

Put this in `Constants.luau` as data, not code, so it's easy to balance without touching logic:

| Parameter | Easy | Medium | Hard |
|---|---|---|---|
| `lookaheadStuds` | short (barely enough to react) | medium | long (reacts early) |
| `reactionDelayTicks` | a few ticks of "hesitation" before acting | minimal | ~0 |
| `mistakeChance` | noticeable chance to pick a non-optimal safe direction | small chance | ~0 |
| `floodFillEnabled` | false (ray heuristic only) | true | true |
| `floodFillInterval` | n/a | slower (e.g. every 15 ticks) | faster (e.g. every 8 ticks) |
| `aggressionWeight` | 0 (pure survival) | low–medium | medium–high |
| `minSegmentLength` | longer (fewer, chunkier turns) | normal | normal/shorter (more precise lines) |

`mistakeChance` and `reactionDelayTicks` matter a lot for "fun" — a perfectly optimal bot from tick one feels robotic and unfair even at "easy." Deliberately imperfect lower tiers read as a *personality*, not a bug.

---

## 7. Performance budget

- Layer 1 (survival check) is 3 line-intersection tests — cheap, run it for every active bot every tick (or every few ticks if bot count is high).
- Layer 2 fast heuristic is a handful more line tests — also cheap, fine every eligible decision tick.
- Flood fill is the only genuinely expensive piece — keep it: (a) on a coarsened grid, (b) budget-capped (stop after N cells, you don't need an exact area count), and (c) throttled per-bot via `floodFillInterval`, ideally staggered across bots so they don't all flood-fill on the same tick.
- Bots only need to *re-evaluate a decision* when there's actually a choice to make (near a potential collision or at a reasonable interval) — you don't need to run the full pipeline every single tick for a bot cruising through open space. A simple "distance to nearest obstacle" cheap check can gate whether the full pipeline runs at all that tick.

---

## 8. Debug/tuning tooling (Studio-only)

Worth having the LLM add a small debug overlay (client-side, gated behind a Studio/dev flag) that draws:
- The 3 candidate projected segments per bot per decision (color-coded safe/unsafe).
- The chosen direction highlighted.
- Optionally, the flood-fill frontier when it runs.

This will make tuning `lookaheadStuds`, `aggressionWeight`, etc. dramatically faster than guessing from behavior alone, and is cheap to strip out for production (single flag).

---

## 9. Phased implementation roadmap


2. **Phase 2 — Space awareness.** Add the fast ray-based heuristic (Layer 2, no flood fill yet). Bot should stop obviously self-trapping in open play.
3. **Phase 3 — Difficulty tiers.** Wire up `Constants.AI_DIFFICULTY`, add `mistakeChance`/`reactionDelayTicks`, add flood fill for medium/hard.
4. **Phase 4 — Strategy layer.** Add player-position prediction and wall-hugging/cut-off weighting for medium/hard.
5. **Phase 5 — Polish.** Debug overlay, staggered flood-fill scheduling across multiple bots, playtesting pass to retune the difficulty table.

Each phase is independently playable and testable — don't wait until Phase 5 to try it against a real player.

---

## 10. Testing checklist

- [ ] Bot never drives itself into a wall it could have seen coming (Layer 1 sanity).
- [ ] Bot doesn't trap itself in an open arena within the first 30s of a match (Layer 2 sanity).
- [ ] Easy bot loses to a mediocre player; Hard bot beats a good player but isn't literally unbeatable.
- [ ] Multiple bots + player simultaneously doesn't drop below tick budget (profile with 3–4 bots at once).
- [ ] AI turns show up correctly on clients via existing `StateUpdate`/`ReplicateTurn` — no bot-specific client code needed.
- [ ] Turning `floodFillEnabled` off degrades gracefully to heuristic-only play (useful fallback if perf is ever an issue).

---

### Note on Safe Zone Spawn Protection

Not core to this plan, but once implemented, the AI's threat/cut-off targeting (Layer 3) should skip treating a spawn-protected player as a valid interception target, and the AI's own collision checks should treat spawn zones as normal open space (not a wall) unless the design intends the zone to block bots too. Flag this as a small follow-up integration point once spawn protection exists.
