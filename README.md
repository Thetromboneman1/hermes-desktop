# Hermes Desktop

Native macOS app for working with Hermes hosts over SSH.

## Purpose

Hermes Desktop keeps remote Hermes workflows native on Mac without introducing an extra API layer or local mirror.

## Core Features

- SSH-native host connection profiles.
- Profile-aware workspace views for sessions, files, usage, skills, and cron jobs.
- Embedded multi-tab SSH terminal.
- Remote editing of canonical Hermes memory/persona files.
- Session browsing and management from remote state.

## Requirements

- macOS 14+
- Working SSH access to target host
- `python3` available on target host
- Remote Hermes state under `~/.hermes`

## Install

1. Download release zip from GitHub releases.
2. Unzip and move `HermesDesktop.app` to Applications.
3. Open the app and configure a connection.

## Connection Options

- SSH alias from `~/.ssh/config`
- Direct host/user/port values
- Optional Hermes profile selection (default or named profile)

## Repo Structure

- `Sources/HermesDesktop/`: app source.
- `Tests/HermesDesktopTests/`: tests.
- `scripts/`: build and packaging scripts.
- `packaging/`: app packaging assets.

## Build

```bash
swift build
```

## Docs

- `RELEASE-v0.5.0.md`
- `scripts/build-macos-app.sh`

## License

See `LICENSE`.
