# Study Timer

A Flutter study timer app with multi-round timer profiles, session persistence, and local notifications.

## Features

- **Timer Profiles** — Study / Training presets with customizable multi-round (work + break) configurations
- **Multi-Cycle Support** — Loop through rounds for a configurable number of cycles (or infinite)
- **Session Persistence** — Automatically saves and restores state on app restart, with wall-clock recovery
- **Local Notifications** — Phase-change alerts via `flutter_local_notifications` + `timezone`
- **Daily Stats** — Accumulated study time and completed rounds per day
- **Custom Profiles** — Add, edit, and delete user-defined timer profiles

## Architecture

```
lib/
├── main.dart                       # Entry point, portrait lock, Material 3
├── models/
│   ├── round_config.dart           # Work + break duration pair
│   ├── timer_profile.dart          # Named profile with round list & cycle config
│   ├── session_state.dart          # In-progress session snapshot
│   ├── daily_record.dart           # Per-day aggregated stats
│   └── study_record.dart           # Single record (not persisted)
├── services/
│   ├── timer_service.dart          # Timer engine (ChangeNotifier, 1s periodic)
│   ├── storage_service.dart        # JSON file persistence
│   └── notification_service.dart   # Local notification scheduling
├── pages/
│   ├── timer_page.dart             # Main timer screen
│   └── preset_edit_page.dart       # Profile editor
└── widgets/
    ├── timer_display.dart          # Countdown display with progress bar
    ├── control_buttons.dart        # Start / Pause / Resume / Stop
    ├── preset_card.dart            # Profile summary card
    ├── stats_card.dart             # Today's stats card
    └── phase_overlay.dart          # Phase transition overlay
```

## Data Flow

```
TimerPage ──start(TimerProfile)──► TimerService (ChangeNotifier)
    ▲                                  │
    │◄─── notifyListeners() ───────────┘
    │                                  │
    │ loadProfiles()          saveSession()
    ▼                                  ▼
StorageService                   current_session.json
    ▲
    │ loadTodayRecord()
    ▼
today_record.json
```

## Testing

25 test cases across 4 suites:

| Suite | File | Tests |
|-------|------|-------|
| App smoke | `test/widget_test.dart` | 3 |
| TimerDisplay | `test/widgets/timer_display_test.dart` | 3 |
| TimerService | `test/services/timer_service_test.dart` | 16 |
| StorageService | `test/services/storage_service_test.dart` | 6 |
