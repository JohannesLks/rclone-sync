# Changelog 📜

All notable changes to **Rclone Sync** are documented here.

## [1.0.3] - 2025-05-07

### Fixed 🐛

- Replaced PowerShell 7 `??` operator with PowerShell 5.1-compatible logic in `Write-Heartbeat` ([Issue #5](https://github.com/your-username/rclone-sync/issues/5)).
- Corrected invalid variable reference in `Test-Remote` (`$_` syntax).
- Fixed `Write-Warning` syntax in `Test-Remote` to properly handle `$_`.
- Added validation and verbose logging for `$Remote` in `Test-Remote` to ensure proper format.
- Resolved `Write-Verbose` syntax error for remote extraction using `${jobIndex}`.
- Fixed `$PSScriptRoot` empty string error with fallback directory detection.
- Corrected typo in `Send-Notification` documentation (`.SYNOPS` → `.SYNOPSIS`).
- Enhanced error handling for file operations, process starts, and configuration validation.
- Added parameter validation and exit code handling for automation.
- Implemented fallbacks for CPU core detection and bandwidth calculations.
- Fixed variable reference errors in strings with colons using `${}` (e.g., `${Remote}`, `${logDir}`).

## [1.0.2] - 2025-05-07

### Added ➕

- Destination remote validation with `rclone lsd` for job destinations.
- Setup guidance for invalid remotes, including `rclone config` instructions.
- Format validation for job destinations (`<remote>:<path>`).

### Changed 🔄

- Updated `README.md` with Rclone remote setup instructions.
- Incremented script version to 1.0.2.

## [1.0.1] - 2025-05-07

### Changed 🔄

- Replaced static bandwidth limits with dynamic limits (50% day, 75% night).
- Added `Test-UploadSpeed` function for upload speed estimation.

## [1.0.0] - 2025-05-07

### Added ➕

- Initial release of `sync_all.ps1` and `create_shortcut.ps1`.
- Parallel Rclone synchronization with time-dependent bandwidth limits (0.6 Mbps 6:00–18:00, 1.2 Mbps 18:00–6:00).
- External JSON configuration (`config.json`).
- Heartbeat monitoring (CPU, memory, progress).
- Desktop notifications and log retention.
- Autostart shortcut creation for Windows.
- Comprehensive documentation and GitHub-ready structure.

---

*Follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) conventions.*