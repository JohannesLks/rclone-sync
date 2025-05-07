# Contributing to Rclone Sync 🤝

Thank you for your interest in contributing to **Rclone Sync**! We welcome contributions in the form of bug reports, feature requests, code, documentation, and more. This guide outlines how to get started.

## Table of Contents

- [Contributing to Rclone Sync 🤝](#contributing-to-rclone-sync-)
  - [Table of Contents](#table-of-contents)
  - [How to Contribute](#how-to-contribute)
    - [Reporting Bugs 🐛](#reporting-bugs-)
    - [Requesting Features ✨](#requesting-features-)
    - [Submitting Pull Requests 🚀](#submitting-pull-requests-)
  - [Development Setup 🛠️](#development-setup-️)
  - [Code Style 📝](#code-style-)
  - [Testing 🧪](#testing-)
  - [Pull Request Checklist ✅](#pull-request-checklist-)
  - [Non-Code Contributions 📖](#non-code-contributions-)
  - [License 📜](#license-)
  - [Contact 📬](#contact-)

## How to Contribute

### Reporting Bugs 🐛

1. **Check Existing Issues**:
   - Search the [issue tracker](https://github.com/your-username/rclone-sync/issues) to avoid duplicates.

2. **Open a Bug Report**:
   - Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md).
   - Provide:
     - Script version (e.g., 1.0.3)
     - Operating system (e.g., Windows 10)
     - PowerShell version (run `$PSVersionTable.PSVersion`)
     - Rclone version (run `rclone --version`)
     - Steps to reproduce
     - Expected and actual behavior
     - Logs (from `scripts/logs/`, use `-Verbose`: `.\scripts\sync_all.ps1 -Verbose > debug.log`)

### Requesting Features ✨

1. **Submit a Feature Request**:
   - Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md).
   - Include:
     - Feature description
     - Use case
     - Proposed implementation (optional)

### Submitting Pull Requests 🚀

1. **Fork and Branch**:
   ```bash
   git clone https://github.com/your-username/rclone-sync.git
   cd rclone-sync
   git checkout -b feature/your-feature
   ```

2. **Make Changes**:
   - Follow [Code Style](#code-style) and [Testing](#testing) guidelines.
   - Update documentation (e.g., `README.md`, `CHANGELOG.md`).

3. **Commit and Push**:
   ```bash
   git commit -m "Add feature X to sync_all.ps1"
   git push origin feature/your-feature
   ```

4. **Open a Pull Request**:
   - Target the `main` branch.
   - Reference related issues (e.g., “Fixes #123”).
   - Complete the [Pull Request Checklist](#pull-request-checklist).

## Development Setup 🛠️

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/rclone-sync.git
   cd rclone-sync
   ```

2. **Install Dependencies**:
   - Install [Rclone](https://rclone.org/downloads/).
   - Configure `scripts/config.json` (see [README.md](README.md)).

3. **Test Locally**:
   ```powershell
   .\scripts\sync_all.ps1 -Verbose
   ```

## Code Style 📝

- **Functions and Variables**: Use PascalCase (e.g., `Test-PathSafety`, `$ScriptDir`).
- **Comment-Based Help**: Include for all functions:
  ```powershell
  <#
  .SYNOPSIS
      Short description
  .PARAMETER Name
      Parameter description
  #>
  ```
- **Parameter Validation**: Use `[Validate*]` attributes (e.g., `[ValidateNotNullOrEmpty()]`).
- **Error Handling**: Use `try`/`catch` for critical operations.
- **Variable Strings**: Use `${variable}` for strings with colons:
  ```powershell
  Write-Warning "Issue with ${variable}: $_"
  ```
- **Linting**: Run [PSScriptAnalyzer](https://github.com/PowerShell/PSScriptAnalyzer):
  ```powershell
  Install-Module -Name PSScriptAnalyzer -Force
  Invoke-ScriptAnalyzer -Path .\scripts\
  ```

## Testing 🧪

- **PowerShell 5.1 Compatibility**:
  ```powershell
  powershell -File .\scripts\sync_all.ps1 -Verbose
  ```

- **Remote Validation**:
  - Test with invalid `rclone.conf` or `Destination`:
    ```powershell
    .\scripts\sync_all.ps1 -Verbose
    ```

- **Script Directory**:
  - Test with and without `-ConfigPath`:
    ```powershell
    .\scripts\sync_all.ps1 -ConfigPath "C:\tools\rclone\scripts\config.json"
    ```

## Pull Request Checklist ✅

Before submitting a PR, ensure:

- [ ] Code follows [Code Style](#code-style).
- [ ] Tests pass in PowerShell 5.1.
- [ ] Documentation updated (`README.md`, `CHANGELOG.md`).
- [ ] No PowerShell 7-specific syntax (e.g., `??`).
- [ ] Linting completed with `Invoke-ScriptAnalyzer`.
- [ ] PR description references related issues.

## Non-Code Contributions 📖

We value:

- **Documentation**: Improve `README.md`, `CONTRIBUTING.md`, or inline comments.
- **Issue Triaging**: Reproduce bugs or clarify feature requests.
- **Feedback**: Suggest UX improvements or new use cases.

## License 📜

Contributions are licensed under the [MIT License](LICENSE).

## Contact 📬

Questions? Open an issue or comment on existing ones at [GitHub Issues](https://github.com/your-username/rclone-sync/issues).