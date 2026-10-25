# فِطنة — FITNA

**تحدَّ عقلك كل يوم** · Arabic-first brain-training game for iPhone (iOS 17+, portrait, fully offline).
A modern spiritual successor to classic mobile brain trainers — all code, art and sound are original.

## Architecture

```
FITNA/                      iOS app (SwiftUI + SwiftData + SpriteKit + Swift Charts, MVVM)
  App/                      entry point, root/tab navigation
  Core/                     localization helpers (L(), LTR isolation for math)
  DesignSystem/             colors, Tajawal typography, tokens
  Components/               reusable views (cards, buttons, rings, tiles…)
  Models/                   SwiftData VersionedSchema (SchemaV1) + migration plan
  Persistence/              container, Store read helpers
  Services/                 GameRecorder (results → difficulty, XP, records, achievements), sound, haptics
  Features/                 Home, Games, BrainAssessment, DailyWorkout, Progress, Profile, Onboarding
  MiniGames/                one folder per game (ViewModel + View), Shared/ host, HUD, tutorial, results
  Resources/                ar.lproj strings, Tajawal fonts (OFL), asset catalog
Packages/FitnaKit/          all game logic — platform independent, unit-tested
  Core/ Scoring/ Progression/ Planning/ Games/
FITNATests/ FITNAUITests/   app integration + UI smoke tests
tools/                      strings source + generator/checker, CI helpers
```

Game logic never touches UIKit: every engine is a deterministic value type driven by a seeded RNG,
and view models pass measured response times in. Puzzle generators validate their answers before use
(unique balance solutions, unambiguous number sequences, derivable patterns, exact divisions…).

## Scoring model (documented in `ScoringModel.swift`)

- **quality** = accuracy (70–90%) + speed vs. per-game reference times (10–30%)
- **performance (0–100)** = 100 × quality × (0.4 + 0.6 × (level−1)/9) → easier levels cap lower
- **category score** = exponentially weighted mean of recent performances; **overall** = mean of categories
- **difficulty** per game: continuous rating, ±0.6 max per session → at most one level step, no spikes
- «مستوى العقل» is an explicitly fictional entertainment tier — not IQ, brain age or a health measure.

## Develop

```bash
cd Packages/FitnaKit && swift test     # game logic tests (macOS or Linux)
xcodegen generate                       # only if project.yml changes (project is committed)
python3 tools/build_strings.py          # regenerate Localizable.strings + verify keys
open FITNA.xcodeproj
```

## CI / TestFlight

- `Build & Test` (every push): FitnaKit tests, simulator build, app unit tests, UI smoke tests.
- `TestFlight` (manual run, push to `release`, or `v*` tag): archive with automatic cloud signing and upload.
  Needs repository secrets `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`
  and an App Store Connect app record for `agency.go360.fitna`.

## Status

See `PROJECT_STATE.md` for what is implemented, tested, and next.
