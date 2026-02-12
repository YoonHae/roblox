# Memory Room MVP (Studio-first)

이 폴더는 `memory-room/memory_room.rbxl`(로컬 Place 파일) 기준으로, **수동 배치 + 빠른 디버그**에 최적화된 MVP 스크립트/가이드를 둡니다.

## 1) Studio에서 권장 구조 만들기

- `Workspace`
  - `Rooms` (Folder)
    - `Room_R0`, `Room_R1` ... (Model)
      - `RoomEntryTrigger` (Part: 바닥 면적, `Transparency=1`, `CanCollide=false`, `CanTouch=true`)
      - `RoomSpawn` (Part: 텔레포트 기준점)
- `ReplicatedStorage`
  - `MemoryRoom` (Folder)
    - `Config` (ModuleScript)
    - `Remotes` (Folder)
- `ServerScriptService`
  - `RoundManager` (Script)
- `StarterPlayer/StarterPlayerScripts`
  - `CameraDirector` (LocalScript)
  - `DebugHud` (LocalScript, 선택)

## 2) Room(Model) Attribute 체크리스트

각 Room(Model)에 Attributes:
- `RoomId` (string) 예: `"R0"`
- `PathIndex` (number) Start=0, Goal=Last, 오답=-1 권장
- `IsStart` (bool)
- `IsGoal` (bool)

## 3) 스크립트 붙이기(복붙)

- `ReplicatedStorage/MemoryRoom/Config` ← `memory-room/scripts/Config.lua` 내용
- `ServerScriptService/RoundManager` ← `memory-room/scripts/RoundManager.server.lua` 내용
- `StarterPlayerScripts/CameraDirector` ← `memory-room/scripts/CameraDirector.client.lua` 내용
- (선택) `StarterPlayerScripts/DebugHud` ← `memory-room/scripts/DebugHud.client.lua` 내용

## 4) 첫 테스트 루틴

1. `Test > Play`
2. 오버뷰가 나오고(카메라 + 방 순서 점등), 이동이 풀리면 방을 밟아 이동
3. 오답 방 진입 시 이전 방 `RoomSpawn`으로 되돌아가는지 확인
4. Output에서 로그 확인, DebugHud 켜져 있으면 상태값 확인

## 5) 자주 막히는 것

- RoomEntryTrigger가 안 먹음: `CanTouch=true`, `CanCollide=false` 확인
- 계속 실패/무한 텔포: Trigger가 벽/문 경계까지 닿아서 오탐 → Trigger를 살짝 inset
- 오버뷰가 안 나옴: `Workspace/Rooms` 폴더명, `PathIndex` 값, `IsStart`/`IsGoal` 확인
- 낙사/리스폰 반복: `RoundManager`는 스폰을 강제 텔포하지 않음(SpawnLocation을 Start 방 안에 두는 방식 권장)
