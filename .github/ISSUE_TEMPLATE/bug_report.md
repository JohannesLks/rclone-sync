---
name: Bug Report 🐛
about: Report a bug to help us improve Rclone Sync
title: "[BUG] "
labels: bug
assignees: ''

---

## Describe the Bug 📝

*A clear and concise description of the issue.*

## Steps to Reproduce 🔄

1. *Step 1 (e.g., Run `.\scripts\sync_all.ps1`)*
2. *Step 2 (e.g., Modify config.json)*
3. *...*

## Expected Behavior ✅

*What you expected to happen.*

## Actual Behavior ❌

*What actually happened.*

## Environment 🌐

- **Script Version**: *e.g., 1.0.3*
- **Operating System**: *e.g., Windows 10*
- **PowerShell Version**: *Run `$PSVersionTable.PSVersion`*
- **Rclone Version**: *Run `rclone --version`*

## Logs 📜

*Attach logs from `scripts/logs/` or paste relevant excerpts. Generate verbose logs with:*
```powershell
.\scripts\sync_all.ps1 -Verbose > debug.log
```

**Example**:
```
WARNING: [Job 1] Destination remote 'gdrive:' is not configured or accessible.
```

## Additional Context ℹ️

*Any other details (e.g., `config.json` snippet, network setup, error screenshots).*

---

*Please provide a minimal, reproducible example if possible.*