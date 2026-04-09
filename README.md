# Hermes Desktop

Native macOS app for Hermes over SSH.

Hermes Desktop gives you the parts of Hermes that matter most on a Mac:
sessions, memories, and a real terminal. In one clean place.

It stays deliberately simple:

- connects directly over SSH
- keeps the Hermes host as the only source of truth
- does not depend on a gateway API
- does not mirror files onto your Mac
- does not install a helper service on the remote host

That is the point of the app. It adds a polished Mac interface around the real
Hermes workflow instead of replacing it with a heavier or more abstract layer.

## What You Get

- a native Mac app, not a browser wrapper
- a real embedded SSH terminal with tabs
- remote editing for:
  - `~/.hermes/memories/USER.md`
  - `~/.hermes/memories/MEMORY.md`
- session browsing from the canonical remote store at `~/.hermes/state.db`
- fallback to `~/.hermes/sessions/*.jsonl` only if the SQLite store is not
  available

Works with:

- Raspberry Pi
- another Mac
- a VPS or remote server
- the same Mac via `ssh localhost`, a local hostname, or a local SSH alias

## Before You Download

You need only a few things:

- macOS 14 or newer
- SSH access that already works from Terminal
- `python3` available on the Hermes host
- Hermes data under the remote user's `~/.hermes`

Simple rule:
if this works in Terminal, the app is usually ready to work too:

```bash
ssh your-host
```

## Install

1. Download `HermesDesktop.app.zip` from GitHub Releases.
2. Double click the zip.
3. Drag `HermesDesktop.app` into `Applications`.
4. Open it.

If macOS blocks the first launch, right click the app and choose `Open` once.

## Connect Your Hermes Host

Open the app, go to `Connections`, create a profile, then click `Test` and
`Connect`.

You have two valid ways to fill the connection:

### Option 1: SSH alias

This is the easiest option.

An SSH alias is just a short name saved in your Mac's SSH config, so instead of
typing a long command every time, you can type something simple like:

```bash
ssh hermes-home
```

That short name usually comes from `~/.ssh/config`.

Example:

```sshconfig
Host hermes-home
  HostName vps.example.com
  User alex
```

In the app:

- set `SSH alias` to `hermes-home`
- leave `Host`, `User`, and `Port` empty unless you want explicit overrides

### Option 2: host details directly

If you normally connect with something like:

```bash
ssh alex@vps.example.com
```

then in the app:

- `Host or IP`: `vps.example.com`
- `User`: `alex`
- `Port`: `22` or your real SSH port

### Same Mac

If Hermes runs on the same Mac, the model stays the same: SSH.

Use one of these:

- `localhost`
- your local hostname
- a local SSH alias

Hermes Desktop still connects over SSH and never reads those files directly.

## What `Test` Checks

`Test` is not a cosmetic button.

It checks that:

- the SSH target is reachable
- authentication works
- `python3` is available in the remote SSH environment used by the app

If `Test` passes, `Connect` should be on solid ground.

## What You Will See In The App

- `Overview`
  Confirms the remote `HOME`, the Hermes root, the tracked memory files, and
  the session source.
- `Files`
  Lets you edit `USER.md` and `MEMORY.md` on the host.
- `Sessions`
  Reads the real remote session store from `~/.hermes/state.db`.
- `Terminal`
  Opens the real SSH shell inside the app.

## Why SSH And A Real Terminal

Hermes is strongest at the command line.

Hermes Desktop keeps that direct path visible and usable: real SSH, real
terminal, real remote files. It does not try to hide Hermes behind a separate
gateway layer or turn it into something else.

## Build From Source

For local development:

```bash
swift run HermesDesktop
```

To build the Mac app bundle:

```bash
./scripts/build-macos-app.sh
```

To create the GitHub Releases archive:

```bash
./scripts/package-github-release.sh
```

Release artifact:

- `dist/HermesDesktop.app.zip`
