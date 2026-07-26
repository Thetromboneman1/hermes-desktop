# Hermes Desktop Repository Maintenance

Last audited: 2026-07-26

`Thetromboneman1/hermes-desktop` is an active downstream fork of
`dodo-reach/hermes-desktop`. The authoritative source branch is upstream
`main`. Downstream files are limited to the governance workflow and manifest,
Pages pinning, and the `AI-Integration.md` and `Operations.md` notes.

`.github/workflows/` is an intentional downstream overlay. The synchronization
merge restores that directory from downstream before pushing because GitHub's
workflow token cannot introduce upstream workflow-file changes. The sync job
still runs the merged Swift suite, so upstream application changes receive
equivalent build and test coverage.

Pushes and pull requests also run the downstream contract and complete Swift
suite through `Repository Validation` on a macOS runner.

The weekly and manual upstream workflow fetches with three bounded attempts,
merges into `automation/upstream-sync-<sha>`, runs the complete Swift test
suite on macOS, and opens or reuses a pull request. It never force-pushes or
directly changes `main`. A conflict creates or updates an issue and fails the
run.

Run local validation with:

```bash
scripts/validate-downstream.sh
```

The current application contract is macOS 14 or later, direct SSH access to
the canonical Hermes host state, and no synchronized mirror. The pending
upstream line adds direct-local transport; synchronization must preserve that
extension as well as SSH. The package is built with Swift Package Manager.
GitHub Pages is deployed from `site/` after a push to `main`.

The only secret reference is GitHub's automatic `GITHUB_TOKEN`. Standard M365
email delivery is not active: this public repository cannot consume the
private Boneman notification action, and the five `M365_*` repository secrets
have not been provisioned through the approved Boneman 1Password vault.

Recovery: close an unmerged synchronization PR and delete its
`automation/upstream-sync-*` branch. Because `main` is not modified by the
workflow, no history rewrite is required.

Maintenance status: active downstream fork.
