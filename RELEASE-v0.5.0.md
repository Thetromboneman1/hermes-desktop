# Hermes Desktop v0.5.0 Release Candidate

Status: prepared, not published.

This document is the working release-prep note for the next public version
after `v0.4.1`.

## Release Positioning

`v0.5.0` should present Hermes Desktop as a mature native companion to Hermes
Agent on macOS.

The thesis stays the same:

- direct SSH to the host
- host remains the source of truth
- no gateway API
- no daemon on the remote host
- no local mirror or shadow sync layer

The important messaging shift is external, not architectural:

- Nous Research now ships the official Hermes web dashboard
- that is good for Hermes Desktop because it clarifies the split
- Hermes Desktop is not the browser dashboard replacement
- Hermes Desktop is the native Mac workspace for direct SSH-based daily use

Use the official dashboard for browser-based management. Use Hermes Desktop for
sessions, canonical files, profile-aware usage, cron workflows, skills, and the
embedded terminal on macOS.

## Scope Since v0.4.1

This scope is based on the code delta from `v0.4.1` to the current branch tip.

- cron jobs became a first-class section, with browse, create, edit, pause,
  resume, run-now, and delete flows against the canonical remote scheduler
  state
- Hermes profile awareness now flows through the app, including profile
  selection on the same host, profile-aware discovery, and profile-aware
  terminal workspace behavior
- usage grew beyond a single active profile view and can now surface host-wide
  totals across readable Hermes profiles when available
- the terminal gained tabs and appearance controls, making it much more viable
  as a long-running native shell surface
- overview and skills flows were tightened to make the host, profile, and
  workspace state easier to read at a glance
- the packaging flow now stamps bundle version metadata during macOS packaging

## What v0.5.0 Should Not Claim

- notarization is still not in place
- Hermes Desktop is not a replacement for the official dashboard
- Hermes Desktop is not a gateway product, daemon product, or sync product
- multi-profile support should be described as profile-aware host workflows, not
  as an entirely separate transport or state model

## Draft GitHub Release Notes

### Hermes Desktop v0.5.0

`v0.5.0` is the release where Hermes Desktop starts to feel complete.

Since `v0.4.1`, the app has grown from a strong SSH-first viewer into a fuller
native workspace for living with Hermes on macOS: cron jobs are now first-class,
Hermes profiles on the same host are treated coherently across the app, the
terminal is more mature with tabs and appearance controls, and usage can now
reflect host-wide profile totals when that data is available.

Just as important, the broader Hermes ecosystem changed in a way that helps this
app. Nous Research now ships the official Hermes web dashboard. That makes the
split cleaner: the official dashboard is the right browser-based management
surface, and Hermes Desktop is the native Mac companion for direct SSH-based
daily use.

This release does not change the core thesis. Hermes Desktop still connects
directly over SSH, keeps the host as the source of truth, avoids helper
services on the remote machine, and does not introduce a second transport model
or local mirror.

#### Highlights

- first-class cron job workflows on the live Hermes host
- profile-aware host workflows across overview, usage, cron, and terminal
- terminal tabs and appearance controls
- stronger overview and workspace clarity
- version-stamped universal macOS packaging

#### Still true

- universal macOS build for Apple Silicon and Intel
- open source
- not notarized yet, so first launch may still require right-click -> Open

## Release Checklist

Do not publish until every item below has been checked from the final release
commit.

- verify the repo is clean with `git status --short --branch`
- verify no private emails, tokens, keys, personal IPs, hostnames, or unsafe
  screenshots are about to ship
- verify `README.md` and release notes are aligned with the final code
- build a fresh app bundle from the final commit:

```bash
HERMES_VERSION=0.5.0 ./scripts/build-macos-app.sh
```

- verify codesign on the built bundle:

```bash
codesign --verify --deep --strict dist/HermesDesktop.app
```

- package a fresh release archive from the same final commit:

```bash
HERMES_VERSION=0.5.0 ./scripts/package-github-release.sh
```

- calculate the release SHA-256:

```bash
shasum -a 256 dist/HermesDesktop.app.zip
```

- publish under a new tag and release asset name for `v0.5.0`
- do not replace or mutate an existing release asset under an old tag

## Manual Verification Focus

Because automated coverage is still light, these flows deserve explicit manual
verification before release:

- connect to a default Hermes profile and verify overview, files, sessions,
  usage, skills, and terminal
- switch to a named Hermes profile on the same host and verify profile-aware
  paths and terminal behavior
- create, edit, pause, resume, trigger, and delete a cron job
- open multiple terminal tabs and confirm theme changes apply cleanly
- verify session browsing and deletion still operate against the intended remote
  store
- verify usage remains correct when only one readable profile is available and
  when more than one profile is available

## Merge Gate

Do not merge to `main` until the current working tree is clean and the exact
`v0.5.0` candidate scope is committed intentionally.

Right now, the branch includes committed feature work since `v0.4.1`, but the
working tree also contains additional uncommitted core changes. Those changes
must either:

- be committed as part of the `v0.5.0` candidate after verification, or
- be excluded from the merge deliberately

Merging to `main` before that line is clear would add avoidable release risk.
