# FITNA — project state

_Last updated: 2026-10-25_

## Implemented

| Milestone | Status |
|---|---|
| 1. Foundation — architecture, design system (brand palette, Tajawal), Arabic RTL localization, 5-tab navigation, skippable 4-page onboarding, home screen, SwiftData versioned schema + migration plan | Done |
| 2. First playable games — ذاكرة الأرقام، تطابق البطاقات، حساب البرق, shared host (tutorial → countdown → HUD/pause → results), recording | Done |
| 3. Remaining nine games — all engines with validated generators + SwiftUI views (تتبّع الكرة uses SpriteKit) | Done |
| 4. Brain test (radar chart, 0–100 overall, history), daily workout generator + flow + summary, adaptive difficulty, XP/levels, 15 achievements, cosmetic avatars | Done |
| 5. Progress dashboard (Swift Charts: overall history, daily activity, categories, period performance, records, improvement), synthesized sounds, haptics, settings toggles | Done |
| 6. Unit tests (FitnaKit: scoring, difficulty, progression, planners, every generator × 10 levels × many seeds), app integration tests, UI smoke tests, app icon, launch screen, CI + TestFlight workflows | Done — first device test pending |

## Verified

- `swift test` in `Packages/FitnaKit` — all game-logic tests pass (also run in CI on macOS).
- iOS simulator build + app tests run on every push via GitHub Actions.

## Known gaps / next tasks

1. Real-device play-test of every game for feel and pacing (timings are tuned on paper).
2. English localization (`en.lproj`) — strings are centralized in `tools/strings_ar.py`.
3. VoiceOver pass on each game; Dynamic Type at the largest sizes in game screens.
4. Optional: daily reminder notification (needs permission prompt).
