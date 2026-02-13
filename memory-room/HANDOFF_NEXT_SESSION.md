# Memory Room Handoff (Test-First)

## Current Verified State

- MVP loop works with manual room placement.
- Room-enter sequence validation works (`PathIndex` ordered check).
- Fail handling teleports player back to previous room `RoomSpawn`.
- Overview works with camera handshake:
  - Server waits for client ready via `Remotes/ClientReady`.
  - Client sends ready on startup and on `CharacterAdded`.
- Overview camera source:
  - Primary: `Workspace/OverviewCamera` part CFrame.
  - Fallback: auto-computed overview CFrame.
- Logging is configurable in `Config.Logging`:
  - `RoomEnter`, `Goal`, `Fail`.

## Files To Re-apply In Studio (if needed)

- `memory-room/scripts/Config.lua`
- `memory-room/scripts/RoundManager.server.lua`
- `memory-room/scripts/CameraDirector.client.lua`

## Test-First Next Work Order

1. Baseline smoke test (no new code)
   - `Test > Play`
   - Verify: overview starts, highlight sequence plays, movement unlocks, fail teleport works.
2. Extract registry module first (low risk)
   - Create `RoomRegistry` module for:
     - room indexing
     - trigger indexing
     - path list generation
   - Keep behavior identical.
   - Retest smoke.
3. Extract round state module second
   - Create `RoundService` module for:
     - per-player state
     - expected index logic
     - success/fail transitions
   - Retest smoke + fail path.
4. Add minimal `DoorController` module
   - Move door open/auto-close behavior from per-door scripts into one controller.
   - Retest door open/close and room-enter logic.
5. Add optional generator skeleton (no runtime switch yet)
   - Add `RoomGenerator` module with API only (no map replacement yet).
   - Keep manual map as default.

## Regression Checklist (run every step)

- Overview starts every play (no intermittent miss).
- Player cannot move during overview; movement restored after.
- Correct path increments index exactly once per room.
- Entering fake room always teleports to previous valid room.
- Goal room prints/flags success once.
- No spam logs unless enabled in `Config.Logging`.

## Known Operational Rules

- Keep `RoomSpawn` as direct child of each room model.
- Keep `RoomSpawn.Anchored = true`.
- `RoomEntryTrigger`: `CanTouch=true`, `CanCollide=false`, inset from walls.
- `OverviewCamera` is optional but recommended for stable angle control.

