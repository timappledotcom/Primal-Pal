# Primal Pal - Greasing the Groove Fitness App

A Flutter app for "Greasing the Groove" style fitness with random exercise snacks throughout the day.

## Setup with FVM

This project uses [FVM](https://fvm.app/) for Flutter version management.

### Install FVM (if not already installed)
```bash
dart pub global activate fvm
```

### Setup Flutter version for this project
```bash
fvm install
fvm use
```

### Running the app
```bash
fvm flutter pub get
fvm flutter run
```

## Features

- **Sport/Rest Day Toggle**: Configure which days focus on Mobility vs Strength exercises
- **Active Window**: Set your daily notification window (e.g., 7 AM - 8 PM)
- **Random Exercise Snacks**: Automatically scheduled notifications throughout the day
- **Progression System**: Exercises get harder (+2 reps) when marked as "Easy"
- **Anti-Repetition**: Exercises performed yesterday won't appear today

## Architecture

- **State Management**: Provider
- **Persistence**: SharedPreferences (JSON encoded)
- **Notifications**: flutter_local_notifications

## Project Structure

```
lib/
├── main.dart
├── models/
│   ├── exercise.dart
│   ├── app_settings.dart
│   └── models.dart
├── providers/
│   ├── exercise_provider.dart
│   ├── settings_provider.dart
│   └── providers.dart
├── screens/
│   ├── home_screen.dart
│   ├── settings_screen.dart
│   ├── active_session_screen.dart
│   └── screens.dart
├── services/
│   ├── storage_service.dart
│   ├── notification_service.dart
│   └── services.dart
└── widgets/
    └── widgets.dart
```
