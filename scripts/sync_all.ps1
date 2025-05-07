<#
.SYNOPSIS
    Performs parallel Rclone synchronization from a NAS with dynamic bandwidth limits based on upload speed.

.DESCRIPTION
    This script synchronizes data from a NAS to cloud storage using Rclone. Key features:
    - Tests maximum upload speed and uses 50% (6:00 AM–6:00 PM) or 75% (6:00 PM–6:00 AM)
    - Validates destination remotes (e.g., gdrive:) before starting sync jobs
    - Provides setup guidance for missing or invalid Rclone remotes
    - Enforces modern TLS versions (TLS 1.2 or higher)
    - Separates PowerShell transcript and Rclone logs
    - Runs jobs in parallel with dynamic transfer settings
    - Uses size-only comparison (no checksum)
    - Provides heartbeat monitoring every 15 seconds (runtime, CPU, memory, log lines, last log write, progress)
    - Warns if no log update for over 5 minutes
    - Terminates with desktop notifications
    - Uses external JSON configuration
    - Includes dependency and network checks
    - Supports parameterized inputs and log retention
    - Compatible with PowerShell 5.1 and later

.PARAMETER ConfigPath
    Path to the JSON configuration file. Defaults to config.json in the script's directory.

.PARAMETER NasServer
    Name of the NAS server for network connectivity checks. Defaults to "nas-schulze".

.PARAMETER Silent
    Suppresses desktop notifications if specified.

.PARAMETER LogRetentionDays
    Number of days to retain log files. Defaults to 30.

.EXAMPLE
    PS> .\sync_all.ps1
    Runs the script with default settings, loading config.json from the script directory.

.EXAMPLE
    PS> .\sync_all.ps1 -ConfigPath "C:\custom\config.json" -Silent -LogRetentionDays 7
    Uses a custom configuration file, suppresses notifications, and retains logs for 7 days.

.NOTES
    Version: 1.0.3
    File: scripts/sync_all.ps1
    ExecutionPolicy: Requires RemoteSigned
    Dependencies: Rclone executable, config.json, valid Rclone remote configuration
    Repository: https://github.com/<your-username>/rclone-sync
    Ensure config.json is configured and Rclone remotes are set up before running.
    Run `rclone config` to configure remotes if destination checks fail.
    Minimum PowerShell version: 5.1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$NasServer = "nas-schulze",

    [Parameter(Mandatory = $false)]
    [switch]$Silent,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 365)]
    [int]$LogRetentionDays = 30
)

# Script version
$ScriptVersion = "1.0.3"

# Determine script directory
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition) }
if (-not $ScriptDir) {
    Write-Error "Unable to determine script directory. Ensure the script is run from a valid directory."
    exit 1
}

# Set default ConfigPath if not provided
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $ScriptDir "config.json"
}

# region Functions

function Test-PathSafety {
    <#
    .SYNOPSIS
        Validates a file or directory path for safety and existence.
    .PARAMETER Path
        The path to validate.
    .OUTPUTS
        Boolean indicating if the path is safe and exists.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    if ($Path -match '[<>|&]') {
        Throw "Invalid characters in path: ${Path}"
    }
    return Test-Path $Path -ErrorAction Stop
}

function Write-Heartbeat {
    <#
    .SYNOPSIS
        Outputs heartbeat information for a running Rclone process.
    .PARAMETER Process
        The process object to monitor.
    .PARAMETER Index
        The job index for logging.
    .PARAMETER LogFile
        Path to the Rclone log file.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,
        [Parameter(Mandatory = $true)]
        [int]$Index,
        [Parameter(Mandatory = $true)]
        [string]$LogFile
    )
    if ($Process.HasExited) {
        if ($Process.ExitCode -ne 0) {
            Write-Warning "[Job $Index] terminated early with ExitCode $($Process.ExitCode). Check ${LogFile} for details."
        }
        return
    }
    try {
        $runTime = (Get-Date) - $Process.StartTime
        $cpu = (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue).CPU
        $memory = (Get-Process -Id $Process.Id -ErrorAction SilentlyContinue).WorkingSet64 / 1MB
        $lineCount = (Get-Content $LogFile -ErrorAction SilentlyContinue | Measure-Object -Line).Lines
        $lastWrite = (Get-Item $LogFile -ErrorAction SilentlyContinue).LastWriteTime
        $matches = Select-String -Path $LogFile -Pattern "Transferred:.*%$"
        $progress = if ($matches) { $matches[$matches.Count - 1] } else { $null }
        $progressValue = if ($progress -and $progress.Matches.Value) { $progress.Matches.Value } else { "N/A" }
        Write-Host ("[Job {0}] running for {1}m{2}s – CPU={3}s, Memory={4}MB, Lines={5}, LastWrite={6}, Progress={7}" `
            -f $Index, [int]$runTime.TotalMinutes, [int]$runTime.Seconds, [math]::Round($cpu, 2), [math]::Round($memory, 2), $lineCount, $lastWrite, $progressValue)
        if ($lastWrite -and ((Get-Date) - $lastWrite -gt [TimeSpan]::FromMinutes(5))) {
            Write-Warning "[Job $Index] no log update for >5 minutes – possibly stalled? Check network or Rclone configuration."
        }
    } catch {
        Write-Warning "[Job $Index] Heartbeat failed: $_"
    }
}

function Send-Notification {
    <#
    .SYNOPSIS
        Displays a desktop notification.
    .PARAMETER Message
        The message to display.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if ($Silent) { return }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipText = $Message
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000)
        Start-Sleep -Seconds 5
        $notify.Dispose()
    } catch {
        Write-Warning "Failed to send notification: $_"
    }
}

function Remove-OldLogs {
    <#
    .SYNOPSIS
        Removes log files older than the specified retention period.
    .PARAMETER LogDir
        Directory containing log files.
    .PARAMETER RetentionDays
        Number of days to retain logs.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogDir,
        [Parameter(Mandatory = $true)]
        [int]$RetentionDays
    )
    try {
        $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
        Get-ChildItem -Path $LogDir -Filter "*.log" -File -ErrorAction Stop | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate } | 
            Remove-Item -Force -ErrorAction Stop
        Write-Verbose "Cleaned up logs older than $RetentionDays days in ${LogDir}"
    } catch {
        Write-Warning "Failed to clean up old logs: $_"
    }
}

function Test-UploadSpeed {
    <#
    .SYNOPSIS
        Estimates the maximum upload speed using a small Rclone test transfer.
    .PARAMETER RcloneExe
        Path to the Rclone executable.
    .PARAMETER RcloneConfig
        Path to the Rclone configuration file.
    .PARAMETER TestRemote
        Remote destination for the test transfer (e.g., gdrive:test).
    .OUTPUTS
        Upload speed in Mbps, or $null if the test fails.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RcloneExe,
        [Parameter(Mandatory = $true)]
        [string]$RcloneConfig,
        [Parameter(Mandatory = $true)]
        [string]$TestRemote
    )
    try {
        # Create a small temporary file (1MB) for testing
        $tempFile = [System.IO.Path]::GetTempFileName()
        $fs = [System.IO.File]::Create($tempFile)
        $fs.Write(([byte[]]::new(1MB)), 0, 1MB)
        $fs.Close()

        # Run Rclone test transfer
        $testLog = Join-Path $logDir "speed_test_$((Get-Date -Format 'yyyyMMdd_HHmmss')).log"
        $args = @(
            "copy", "--progress",
            "--config", $RcloneConfig,
            "--size-only", "--log-level", "INFO",
            "--log-file", $testLog,
            $tempFile, "$TestRemote/speedtest"
        )
        $process = Start-Process -FilePath $RcloneExe -ArgumentList $args -NoNewWindow -PassThru -Wait -ErrorAction Stop

        if ($process.ExitCode -ne 0) {
            Write-Warning "Upload speed test failed. Check ${testLog} for details."
            return $null
        }

        # Parse speed from log (look for "Transferred: ... /s")
        $logContent = Get-Content $testLog -ErrorAction SilentlyContinue
        $speedMatch = $logContent | Select-String "Transferred:.*?\((.*?/s)\)" | Select-Object -Last 1
        if ($speedMatch) {
            $speedText = $speedMatch.Matches.Groups[1].Value
            if ($speedText -match "(\d+\.?\d*)\s*([KMG]i?B/s)") {
                $value = [double]$matches[1]
                $unit = $matches[2]
                $speedMbps = switch ($unit) {
                    "B/s" { $value * 8 / 1MB }  # Convert B/s to Mbps
                    "KB/s" { $value * 8 / 1000 } # Convert KB/s to Mbps
                    "MB/s" { $value * 8 }        # Convert MB/s to Mbps
                    "GB/s" { $value * 8000 }     # Convert GB/s to Mbps
                    default { $null }
                }
                if ($speedMbps) {
                    Write-Host "Estimated upload speed: $speedMbps Mbps"
                    return $speedMbps
                }
            }
        }
        Write-Warning "Could not parse upload speed from ${testLog}."
        return $null
    } catch {
        Write-Warning "Upload speed test failed: $_"
        return $null
    } finally {
        if (Test-Path $tempFile -ErrorAction SilentlyContinue) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path $testLog -ErrorAction SilentlyContinue) { Remove-Item $testLog -Force -ErrorAction SilentlyContinue }
    }
}

function Test-Remote {
    <#
    .SYNOPSIS
        Validates that an Rclone remote is configured and accessible.
    .PARAMETER RcloneExe
        Path to the Rclone executable.
    .PARAMETER RcloneConfig
        Path to the Rclone configuration file.
    .PARAMETER Remote
        The remote to test (e.g., gdrive:).
    .OUTPUTS
        Boolean indicating if the remote is valid and accessible.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$RcloneExe,
        [Parameter(Mandatory = $true)]
        [string]$RcloneConfig,
        [Parameter(Mandatory = $true)]
        [string]$Remote
    )
    Write-Verbose "Testing remote: ${Remote}"
    if (-not $Remote -or $Remote -notmatch '^[^:]+:$') {
        Write-Warning "Invalid remote format: '${Remote}'. Expected format: '<remote>:'. Skipping validation."
        return $false
    }
    try {
        $args = @(
            "lsd", $Remote,
            "--config", $RcloneConfig,
            "--log-level", "ERROR"
        )
        $process = Start-Process -FilePath $RcloneExe -ArgumentList $args -NoNewWindow -PassThru -Wait -ErrorAction Stop
        if ($process.ExitCode -eq 0) {
            Write-Verbose "Remote ${Remote} is accessible."
            return $true
        } else {
            Write-Warning "Remote ${Remote} is not accessible (ExitCode: $($process.ExitCode)). Run 'rclone config' to set it up or check ${RcloneConfig}."
            return $false
        }
    } catch {
        Write-Warning "Failed to validate remote ${Remote}: $_. Run 'rclone config' to set it up or check ${RcloneConfig}."
        return $false
    }
}

# endregion

# region Initialization

# Check for non-Windows systems
if ($PSVersionTable.PSVersion.Platform -and $PSVersionTable.PSVersion.Platform -ne "Win32NT") {
    Write-Warning "This script is optimized for Windows. Some features (e.g., NAS paths, notifications) may not work on $($PSVersionTable.PSVersion.Platform)."
}

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Error "This script requires PowerShell 5.1 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Check for running Rclone instances
if (Get-Process -Name "rclone" -ErrorAction SilentlyContinue) {
    Write-Warning "Another Rclone instance is already running!"
    Send-Notification "Rclone sync aborted: Another instance is running"
    exit 1
}

# Load configuration
try {
    if (-not (Test-PathSafety $ConfigPath)) {
        Throw "Configuration file not found: ${ConfigPath}. Ensure config.json exists in the script directory."
    }
    $config = Get-Content $ConfigPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Error "Failed to load configuration: $_. Ensure config.json is valid JSON at ${ConfigPath}."
    Send-Notification "Rclone sync aborted: Configuration error"
    exit 1
}

# Validate configuration properties
if (-not $config.NasPath -or -not $config.RcloneExe -or -not $config.RcloneConfig -or -not $config.LogDir -or -not $config.Jobs) {
    Write-Error "Invalid configuration: Missing required fields (NasPath, RcloneExe, RcloneConfig, LogDir, or Jobs) in ${ConfigPath}."
    Send-Notification "Rclone sync aborted: Invalid configuration"
    exit 1
}

# Resolve relative paths
$nasPath = $config.NasPath
$rcloneExe = if ($config.RcloneExe -match '^[a-zA-Z]:\\') { $config.RcloneExe } else { Join-Path $ScriptDir $config.RcloneExe }
$rcloneConfig = if ($config.RcloneConfig -match '^[a-zA-Z]:\\') { $config.RcloneConfig } else { Join-Path $ScriptDir $config.RcloneConfig }
$logDir = if ($config.LogDir -match '^[a-zA-Z]:\\') { $config.LogDir } else { Join-Path $ScriptDir $config.LogDir }
$maxTries = if ($config.MaxTries -ge 1) { $config.MaxTries } else { 10 }
$jobs = $config.Jobs

# Validate dependencies
if (-not (Test-PathSafety $rcloneExe)) {
    Write-Error "Rclone executable not found: ${rcloneExe}. Install Rclone and update config.json."
    Send-Notification "Rclone sync aborted: Rclone executable missing"
    exit 1
}
if (-not (Test-PathSafety $rcloneConfig)) {
    Write-Error "Rclone configuration file not found: ${rcloneConfig}. Create rclone.conf and update config.json."
    Send-Notification "Rclone sync aborted: Rclone configuration missing"
    exit 1
}

# Check network connectivity
try {
    if (-not (Test-Connection -ComputerName $NasServer -Count 2 -Quiet -ErrorAction Stop)) {
        Write-Error "No network connection to ${NasServer}. Check network settings and try again."
        Send-Notification "Rclone sync aborted: No network connection"
        exit 1
    }
} catch {
    Write-Error "Network connectivity check failed: $_. Check NasServer configuration."
    Send-Notification "Rclone sync aborted: Network check failed"
    exit 1
}

# Wait for NAS path availability
$tryCount = 1
while (-not (Test-PathSafety $nasPath) -and $tryCount -le $maxTries) {
    Write-Host "Attempt ${tryCount}: Waiting for NAS (${nasPath})..."
    Start-Sleep -Seconds (6 * $tryCount)  # Exponential backoff
    $tryCount++
}
if (-not (Test-PathSafety $nasPath)) {
    Write-Error "Network path ${nasPath} not available after $maxTries attempts – aborting!"
    Send-Notification "Rclone sync aborted: NAS unavailable"
    exit 1
}

Write-Host "NAS reachable – proceeding with Rclone (Version $ScriptVersion)."

# Validate destination remotes
$validJobs = @()
foreach ($job in $jobs) {
    $jobIndex = $jobs.IndexOf($job) + 1
    if (-not $job.Destination) {
        Write-Warning "[Job $jobIndex] Destination is empty. Skipping job."
        continue
    }
    if (-not ($job.Destination -match '^[^:]+:.*')) {
        Write-Warning "[Job $jobIndex] Invalid destination format: '$($job.Destination)'. Expected '<remote>:<path>'. Skipping job."
        continue
    }
    $Remote = $job.Destination -replace ':.*$', ':'
    Write-Verbose "Extracted remote for job ${jobIndex}: ${Remote}"
    if (-not $Remote) {
        Write-Warning "[Job $jobIndex] Could not extract remote from destination '$($job.Destination)'. Skipping job."
        continue
    }
    if (Test-Remote -RcloneExe $rcloneExe -RcloneConfig $rcloneConfig -Remote $Remote) {
        $validJobs += $job
    } else {
        Write-Warning "[Job $jobIndex] Destination remote '${Remote}' is not configured or accessible. Skipping job."
        Write-Host "To set up the remote, run: rclone config"
        Write-Host "See https://rclone.org/docs/ for configuration instructions."
    }
}

if ($validJobs.Count -eq 0) {
    Write-Error "No valid destination remotes found. Configure at least one remote in ${rcloneConfig} and update config.json."
    Send-Notification "Rclone sync aborted: No valid destination remotes"
    exit 1
}

Write-Host "Validated $($validJobs.Count) of $($jobs.Count) jobs with accessible destination remotes."

# endregion

# region Setup

# Set flexible TLS versions
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
} catch {
    Write-Warning "Failed to set TLS versions: $_. Using default security protocol."
}

# Initialize log directory and clean up old logs
if (-not (Test-PathSafety $logDir)) {
    try {
        New-Item -Path $logDir -ItemType Directory -ErrorAction Stop | Out-Null
    } catch {
        Write-Error "Failed to create log directory ${logDir}: $_"
        Send-Notification "Rclone sync aborted: Log directory creation failed"
        exit 1
    }
}
Remove-OldLogs -LogDir $logDir -RetentionDays $LogRetentionDays

# Generate unique log filenames
$timeStamp = Get-Date -Format "yyyyMMdd_HHmmss_ffff"  # Unique with milliseconds
$transcriptLog = Join-Path $logDir "sync_transcript_$timeStamp.log"
$rcloneLog = Join-Path $logDir "sync_rclone_$timeStamp.log"

# Start PowerShell transcript
try {
    Start-Transcript -Path $transcriptLog -Append -NoClobber -ErrorAction Stop
} catch {
    Write-Warning "Failed to start transcript: $_. Continuing without transcript."
}

# endregion

# region Rclone Configuration

# Dynamic parallelism based on CPU cores
$cpuCores = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue).NumberOfCores
$transfers = if ($cpuCores) { [math]::Min(32, $cpuCores * 8) } else { 16 }
$checkers = $transfers

# Test upload speed and calculate bandwidth limit
$maxUploadSpeed = Test-UploadSpeed -RcloneExe $rcloneExe -RcloneConfig $rcloneConfig -TestRemote ($validJobs[0].Destination -replace "/.*$","")
if ($null -eq $maxUploadSpeed) {
    Write-Warning "Upload speed test failed. Falling back to static bandwidth limits."
    $maxUploadSpeed = 2.4  # Fallback: Assume 2.4 Mbps
}
$currentTime = Get-Date
$bandwidthPercent = if ($currentTime.Hour -ge 6 -and $currentTime.Hour -lt 18) { 0.5 } else { 0.75 }  # 50% day, 75% night
$totalBandwidthMbps = $maxUploadSpeed * $bandwidthPercent
$bandwidthLimit = [math]::Round($totalBandwidthMbps * 1000 / 8 / [math]::Max(1, $validJobs.Count), 2)  # Convert Mbps to KB/s per job
Write-Host "Maximum upload speed: $maxUploadSpeed Mbps"
Write-Host "Bandwidth limit: $totalBandwidthMbps Mbps total ($bandwidthLimit KB/s per job, $bandwidthPercent of max)"

# Performance-optimized Rclone arguments
$baseArgs = @(
    "sync", "--progress",
    "--config", $rcloneConfig,
    "--transfers", $transfers, "--checkers", $checkers,
    "--drive-chunk-size", "512M", "--buffer-size", "2G",
    "--multi-thread-streams", "8", "--multi-thread-cutoff", "64M",
    "--size-only", "--fast-list",
    "--log-level", "INFO", "--stats", "15s",
    "--log-file", $rcloneLog,
    "--bwlimit", "$bandwidthLimit"
)

Write-Host "`n=== Starting parallel sync jobs ($($validJobs.Count)) – Log: ${rcloneLog} ===`n"

# endregion

# region Job Execution

$processes = @()
for ($i = 0; $i -lt $validJobs.Count; $i++) {
    $job = $validJobs[$i]
    $jobIndex = $i + 1
    if (-not $job.Source -or -not (Test-PathSafety $job.Source)) {
        Write-Warning "[Job $jobIndex] Source '$($job.Source)' not found or empty, skipping."
        continue
    }
    $jobArgs = $baseArgs + @($job.Source, $job.Destination)
    if ($job.Exclude) { $jobArgs += "--exclude"; $jobArgs += $job.Exclude }
    Write-Host "[Job $jobIndex] Starting rclone $($jobArgs -join ' ')"
    try {
        $processes += Start-Process -FilePath $rcloneExe -ArgumentList $jobArgs -NoNewWindow -PassThru -ErrorAction Stop
        Start-Sleep -Seconds 2
    } catch {
        Write-Warning "[Job $jobIndex] Failed to start Rclone process: $_"
    }
}

# endregion

# region Heartbeat and Monitoring

$lastBandwidthLimit = $bandwidthLimit
$lastHour = $currentTime.Hour
while ($processes.Where({ -not $_.HasExited }).Count -gt 0) {
    Start-Sleep -Seconds 15
    # Check bandwidth limit at hour change
    $currentTime = Get-Date
    if ($currentTime.Hour -ne $lastHour) {
        $newBandwidthPercent = if ($currentTime.Hour -ge 6 -and $currentTime.Hour -lt 18) { 0.5 } else { 0.75 }
        $newTotalBandwidthMbps = $maxUploadSpeed * $newBandwidthPercent
        $newBandwidthLimit = [math]::Round($newTotalBandwidthMbps * 1000 / 8 / [math]::Max(1, $validJobs.Count), 2)
        if ($newBandwidthLimit -ne $lastBandwidthLimit) {
            Write-Host "Bandwidth limit changing to $newTotalBandwidthMbps Mbps total ($newBandwidthLimit KB/s per job, $newBandwidthPercent of max) – restarting jobs"
            $processes | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
            $processes = @()
            for ($i = 0; $i -lt $validJobs.Count; $i++) {
                $job = $validJobs[$i]
                $jobIndex = $i + 1
                if (-not $job.Source -or -not (Test-PathSafety $job.Source)) { continue }
                $jobArgs = $baseArgs + @($job.Source, $job.Destination)
                if ($job.Exclude) { $jobArgs += "--exclude"; $jobArgs += $job.Exclude }
                $jobArgs = $jobArgs -replace "--bwlimit\s+$lastBandwidthLimit", "--bwlimit $newBandwidthLimit"
                try {
                    $processes += Start-Process -FilePath $rcloneExe -ArgumentList $jobArgs -NoNewWindow -PassThru -ErrorAction Stop
                    Start-Sleep -Seconds 2
                } catch {
                    Write-Warning "[Job $jobIndex] Failed to restart Rclone process: $_"
                }
            }
            $lastBandwidthLimit = $newBandwidthLimit
        }
        $lastHour = $currentTime.Hour
    }
    foreach ($process in $processes) {
        Write-Heartbeat -Process $process -Index ($processes.IndexOf($process) + 1) -LogFile $rcloneLog
    }
}

# endregion

# region Cleanup

# Check exit codes
$allSuccessful = $true
for ($i = 0; $i -lt $processes.Count; $i++) {
    $process = $processes[$i]
    $jobIndex = $i + 1
    if ($process.HasExited) {
        if ($process.ExitCode -eq 0) {
            Write-Host "[Job $jobIndex] completed successfully in $((Get-Date) - $process.StartTime)."
        } else {
            Write-Warning "[Job $jobIndex] terminated with ExitCode $($process.ExitCode) – see ${rcloneLog} for details."
            $allSuccessful = $false
        }
    }
}

Write-Host "=== All jobs completed! ==="

# Stop transcript
try {
    Stop-Transcript -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Failed to stop transcript: $_"
}
Write-Host "`nPowerShell Transcript: ${transcriptLog}"
Write-Host "Rclone Log:           ${rcloneLog}"

# Send notification
$notificationMessage = if ($allSuccessful) { "Rclone sync completed successfully" } else { "Rclone sync completed with errors – see ${rcloneLog}" }
Send-Notification $notificationMessage

# Exit with appropriate code
exit $(if ($allSuccessful) { 0 } else { 1 })

# endregion