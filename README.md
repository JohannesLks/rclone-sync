# Rclone Sync 📥

![Rclone Sync](https://via.placeholder.com/800x200.png?text=Rclone+Sync) <!-- Placeholder for logo -->

A PowerShell-based solution for **parallel Rclone synchronization** from a NAS to cloud storage with dynamic bandwidth limits.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1+-blue)](https://docs.microsoft.com/en-us/powershell/)
[![Rclone Version](https://img.shields.io/badge/Rclone-1.65+-green)](https://rclone.org/)

## Table of Contents

- [Rclone Sync 📥](#rclone-sync-)
  - [Table of Contents](#table-of-contents)
  - [Features ✨](#features-)
  - [Prerequisites 📋](#prerequisites-)
  - [Installation 🚀](#installation-)
  - [Configuration ⚙️](#configuration-️)
    - [Setting Up Rclone Remotes 🔗](#setting-up-rclone-remotes-)
  - [Usage 🛠️](#usage-️)
  - [Testing 🧪](#testing-)
  - [Troubleshooting 🔍](#troubleshooting-)
  - [Contributing 🤝](#contributing-)
  - [License 📜](#license-)
  - [FAQ ❓](#faq-)
  - [Contact 📬](#contact-)

## Features ✨

- **Parallel Synchronization**: Sync multiple directories concurrently using Rclone.
- **Dynamic Bandwidth Limits**:
  - 50% of max upload speed (6:00 AM–6:00 PM)
  - 75% of max upload speed (6:00 PM–6:00 AM)
- **Remote Validation**: Checks cloud storage remotes (e.g., Google Drive, Dropbox) before syncing.
- **Heartbeat Monitoring**: Tracks CPU, memory, and progress every 15 seconds.
- **Desktop Notifications**: Alerts on completion or errors.
- **External JSON Configuration**: Flexible setup via `config.json`.
- **Autostart Support**: Runs automatically via Windows shortcuts.
- **Robust Error Handling**: Comprehensive logging and recovery mechanisms.
- **PowerShell 5.1 Compatible**: Works on Windows with minimal dependencies.

## Prerequisites 📋

Before you begin, ensure you have:

- **Windows OS** with PowerShell 5.1 or later
- **Rclone** installed ([download](https://rclone.org/downloads/))
- **PowerShell ExecutionPolicy** set to `RemoteSigned`:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
  ```
- **Configured Rclone remote** (e.g., Google Drive, Dropbox) in `rclone.conf`

## Installation 🚀

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/rclone-sync.git
   cd rclone-sync
   ```

2. **Copy Example Configuration**:
   ```bash
   cp examples/config.example.json scripts/config.json
   ```

3. **Configure Paths**:
   - Ensure `rclone.exe` and `rclone.conf` are in `scripts/` or update `config.json` with their paths.

## Configuration ⚙️

Edit `scripts/config.json` to match your setup:

| Field         | Description                                  | Example                              |
|---------------|----------------------------------------------|--------------------------------------|
| `NasPath`     | Path to your NAS share                       | `\\nas-schulze\EigeneDateien`        |
| `RcloneExe`   | Path to `rclone.exe` (relative or absolute)  | `C:\tools\rclone\rclone.exe`         |
| `RcloneConfig`| Path to `rclone.conf`                        | `C:\tools\rclone\rclone.conf`        |
| `LogDir`      | Directory for logs                           | `C:\tools\rclone\logs`               |
| `MaxTries`    | Attempts to connect to NAS                   | `10`                                 |
| `Jobs`        | Array of sync jobs                           | See example below                    |

**Example `config.json`**:
```json
{
    "NasPath": "\\\\your-nas-server\\your-share",
    "RcloneExe": "rclone.exe",
    "RcloneConfig": "rclone.conf",
    "LogDir": "logs",
    "MaxTries": 10,
    "Jobs": [
        { "Source": "\\\\your-nas-server\\your-share\\path1", "Destination": "remote:path1", "Exclude": null },
        { "Source": "\\\\your-nas-server\\your-share\\path2", "Destination": "remote:path2", "Exclude": "exclude/path/**" }
    ]
}
```

### Setting Up Rclone Remotes 🔗

1. **Configure a Remote**:
   ```bash
   rclone config
   ```
   Follow prompts to set up your cloud storage (e.g., Google Drive, Dropbox). Refer to [Rclone docs](https://rclone.org/docs/).

2. **Verify Remote**:
   Ensure `rclone.conf` (e.g., `C:\tools\rclone\rclone.conf`) includes your remote (e.g., `[gdrive]`).

3. **Test Remote**:
   ```bash
   rclone lsd gdrive:
   ```
   If this fails, re-run `rclone config` or check credentials.

> **Note**: The script validates each job’s destination remote before syncing, skipping invalid ones with setup instructions.

## Usage 🛠️

1. **Run the Main Script**:
   ```powershell
   .\scripts\sync_all.ps1
   ```

2. **Create an Autostart Shortcut**:
   ```powershell
   .\scripts\create_shortcut.ps1
   ```

3. **Optional Parameters**:
   ```powershell
   .\scripts\sync_all.ps1 -ConfigPath "custom.json" -Silent -LogRetentionDays 7
   .\scripts\create_shortcut.ps1 -Global
   ```

## Testing 🧪

1. **Verify Rclone**:
   ```bash
   rclone --version
   ```

2. **Test the Script**:
   ```powershell
   .\scripts\sync_all.ps1 -Verbose
   ```

3. **Check Logs**:
   Inspect logs in `scripts/logs/` for validation results and job progress.

4. **Test Autostart**:
   Reboot to confirm the shortcut runs `sync_all.ps1`.

## Troubleshooting 🔍

If you encounter issues, try these steps:

- **Syntax Errors in PowerShell 5.1**:
  - Verify PowerShell version:
    ```powershell
    $PSVersionTable.PSVersion
    ```
  - Ensure PowerShell 5.1 or later. Save scripts with UTF-8 encoding and avoid PowerShell 7 syntax (e.g., `??` operator).

- **Variable Reference Errors**:
  - For errors like “Invalid variable reference” (e.g., `$Remote:`), use `${variable}` in strings:
    ```powershell
    Write-Warning "Failed to validate remote ${Remote}: $_. Run 'rclone config'..."
    ```
  - Common issue: Colons after variables. Fix:
    ```powershell
    # Incorrect
    Write-Warning "Remote $Remote: $_..."
    # Correct
    Write-Warning "Remote ${Remote}: $_..."
    ```

- **Empty Script Directory ($PSScriptRoot)**:
  - Run from the script’s directory:
    ```powershell
    cd C:\tools\rclone\scripts
    .\sync_all.ps1
    ```
  - Or specify `-ConfigPath`:
    ```powershell
    .\scripts\sync_all.ps1 -ConfigPath "C:\tools\rclone\scripts\config.json"
    ```

- **Destination Remote Errors**:
  - Test remote:
    ```bash
    rclone lsd gdrive:
    ```
  - If it fails, re-run `rclone config`. Ensure `Destination` in `config.json` is `<remote>:<path>` (e.g., `gdrive:backup`).
  - Debug with:
    ```powershell
    .\scripts\sync_all.ps1 -Verbose
    ```

For detailed logs, run:
```powershell
.\scripts\sync_all.ps1 -Verbose > debug.log
```

## Contributing 🤝

Contributions are welcome! To get started:

- **Report Bugs**: Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).
- **Request Features**: Submit a [feature request](.github/ISSUE_TEMPLATE/feature_request.md).
- **Submit Pull Requests**: Follow the guidelines in [CONTRIBUTING.md](CONTRIBUTING.md).

Test changes with:
```powershell
.\scripts\sync_all.ps1 -Verbose
```

## License 📜

This project is licensed under the [MIT License](LICENSE).

## FAQ ❓

- **Why do I get an ExecutionPolicy error?**
  Run:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
  ```

- **Why is my destination remote invalid?**
  Configure and test:
  ```bash
  rclone config
  rclone lsd gdrive:
  ```

- **Where are logs stored?**
  In `LogDir` from `config.json` (default: `scripts/logs`).

- **How do I disable notifications?**
  Use:
  ```powershell
  .\sync_all.ps1 -Silent
  ```

- **Why do I get syntax errors?**
  Ensure PowerShell 5.1+ and no PowerShell 7 syntax (e.g., `??`).

- **Why does the script report an undefined remote?**
  Verify `Destination` in `config.json` is `<remote>:<path>`. Debug with:
  ```powershell
  .\scripts\sync_all.ps1 -Verbose
  ```

## Contact 📬

For support, open an issue on [GitHub](https://github.com/your-username/rclone-sync/issues). Include verbose logs:
```powershell
.\scripts\sync_all.ps1 -Verbose > debug.log
```
