# uMacCleaner

A native macOS cleanup app and command line tool. Sprint 1 scans the current user's caches, logs, and Xcode DerivedData, then moves selected top-level items to Trash.

The GUI also supports name/path filtering, size/name/category sorting, select/deselect visible items, and scanning a chosen folder or external volume. Chosen folders are treated as user data, not automatically classified as junk. The System Data trace lists likely contributors, with Finder links and a review path for caches, logs, and Derived Data. Its totals are estimates and can overlap; it cannot exactly reproduce macOS Storage's System Data number.

## Run

- GUI: `swift run uMacCleaner-GUI`
- App bundle: `zsh scripts/build-app.sh`, then open `dist/uMacCleaner-GUI.app`
- CLI preview: `swift run uMacCleaner-CLI scan`
- CLI JSON: `swift run uMacCleaner-CLI scan --json`
- CLI System Data trace: `swift run uMacCleaner-CLI trace`
- Docker disk usage: `swift run uMacCleaner-CLI docker`
- Docker build cache cleanup: `swift run uMacCleaner-CLI docker-prune-build --yes`
- CLI cleanup: `swift run uMacCleaner-CLI clean --yes --category logs`
- Tests: `swift test`

The app requires macOS 14 or later. macOS may ask for file access. Close active apps before removing their caches; some files will be recreated. Trash can be emptied later in Finder.

## CI and releases

GitHub Actions runs tests, builds both binaries, and publishes releases on a runner with the `self-hosted` label. This workflow requires that runner to be a macOS ARM64 machine. It runs for pushes to `master`, pull requests targeting `master`, version tags, and manual triggers. Each successful build offers separate GUI and CLI ZIP downloads. The CLI is also bundled inside `uMacCleaner-GUI.app/Contents/MacOS/uMacCleaner-CLI`. A push to `master` publishes the version in `VERSION` (initially `v0.1.0`) if that release does not already exist. To publish another version, bump `VERSION` and push to `master`, or push a matching `v*` tag. The release assets are `uMacCleaner-GUI-macOS-arm64.zip` and `uMacCleaner-CLI-macOS-arm64.zip`, with SHA-256 checksums in the release notes. If an existing release has only the GUI ZIP, the next `master` push builds its CLI ZIP from that release's app bundle and attaches it. GitHub automatically adds source-code archive links to every release. Pull requests and manual runs upload workflow artifacts but do not publish releases. The runner needs Xcode/Swift and Homebrew; the release job installs GitHub CLI through Homebrew if it is missing.

The app is ad hoc signed for packaging but is **not notarized**. macOS Gatekeeper may require users to approve opening a downloaded build. A public release should later use an Apple Developer ID certificate and notarization.

Docker diagnostics use Docker's CLI to report images, containers, local volumes, and build cache. The only Docker cleanup action prunes build cache after confirmation; it does not delete volumes or Docker's disk image. The Apple Intelligence page points to supported macOS settings. It does not delete protected model assets or use private system changes.

## Sprints

1. **Foundation — implemented:** shared scanner, reviewable SwiftUI list, explicit Trash action, CLI scan/clean, path safety tests.
2. **Better discovery:** browser and app-specific rules, stale-file detection, exclusions, and category descriptions.
3. **Pro workflow:** saved presets, scheduled scans, CLI filters, per-item details, and exportable reports.
4. **Broader utilities:** large/duplicate file discovery, uninstall review, and maintenance actions with per-action confirmation.
5. **Release:** accessibility and permission handling, signed/notarized builds, onboarding, and performance work.

The scope of each later feature needs its own safety rules. System-protected areas and automatic permanent deletion are outside the current implementation.
