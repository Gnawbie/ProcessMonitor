# ============================================================
#  ProcessMonitor.ps1  -  System-wide process exit logger
#  Logs all program closes; flags non-zero exit codes as errors
#  Shows a system tray icon while running
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ── Config ───────────────────────────────────────────────────
$LogDir      = Join-Path $env:USERPROFILE "ProcessMonitorLogs"
$PidFile     = Join-Path $LogDir ".monitor.pid"
$SettingsFile = Join-Path $LogDir "settings.cfg"

$SkipPIDs  = @(0, 4)
$SkipNames = @("System", "Idle", "Registry", "smss.exe", "csrss.exe")

# ── Setup ────────────────────────────────────────────────────
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

$PID | Out-File -FilePath $PidFile -Encoding ASCII -Force

# ── Helpers ──────────────────────────────────────────────────
function Get-LogPaths {
    $date = Get-Date -Format "yyyy-MM-dd"
    return @{
        All    = Join-Path $LogDir "process_$date.log"
        Errors = Join-Path $LogDir "errors_$date.log"
    }
}

function Write-Entry {
    param([string]$Line, [bool]$IsError)
    $paths = Get-LogPaths
    Add-Content -Path $paths.All -Value $Line -Encoding UTF8
    if ($IsError) {
        Add-Content -Path $paths.Errors -Value $Line -Encoding UTF8
    }
}

function Format-ExitCode {
    param([uint32]$Code)
    if ($Code -eq 0) { return "0 (clean)" }
    $hex = "0x{0:X8}" -f $Code
    return "$Code ($hex)"
}

# ── Build tray icon (drawn with GDI+ - no .ico file needed) ──
function New-TrayIcon {
    param([string]$Color = "Green")

    $bmp = New-Object System.Drawing.Bitmap 16, 16
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $fill   = if ($Color -eq "Green") { [System.Drawing.Color]::FromArgb(40, 200, 80) } `
              else                    { [System.Drawing.Color]::FromArgb(220, 60, 60) }
    $border = if ($Color -eq "Green") { [System.Drawing.Color]::FromArgb(20, 140, 50) } `
              else                    { [System.Drawing.Color]::FromArgb(160, 30, 30) }

    $brush = New-Object System.Drawing.SolidBrush $fill
    $pen   = New-Object System.Drawing.Pen $border, 1.5

    $g.FillEllipse($brush, 1, 1, 13, 13)
    $g.DrawEllipse($pen,   1, 1, 13, 13)

    $g.Dispose()
    $brush.Dispose()
    $pen.Dispose()

    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

# ── Tray icon setup ───────────────────────────────────────────
$tray         = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = New-TrayIcon -Color "Green"
$tray.Visible = $true

# Right-click context menu
$menu        = New-Object System.Windows.Forms.ContextMenuStrip

$menuTitle   = New-Object System.Windows.Forms.ToolStripMenuItem
$menuTitle.Text    = "Process Monitor"
$menuTitle.Enabled = $false
$menu.Items.Add($menuTitle) | Out-Null
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuLogs    = New-Object System.Windows.Forms.ToolStripMenuItem
$menuLogs.Text = "Open Log Folder"
$menuLogs.Add_Click({ Start-Process explorer $LogDir })
$menu.Items.Add($menuLogs) | Out-Null

# Load persisted mute state
$script:Muted = $false
if (Test-Path $SettingsFile) {
    $saved = Get-Content $SettingsFile | ConvertFrom-StringData
    if ($saved.Muted -eq "true") { $script:Muted = $true }
}

$menuMute = New-Object System.Windows.Forms.ToolStripMenuItem
$menuMute.Text        = "Mute Notifications"
$menuMute.CheckOnClick = $true
$menuMute.Checked     = $script:Muted
$menuMute.Add_Click({
    $script:Muted = $menuMute.Checked
    # Persist to disk
    "Muted=$($script:Muted.ToString().ToLower())" | Set-Content $SettingsFile -Encoding ASCII
    if ($script:Muted) {
        $tray.Text = "Process Monitor - Running (muted)"
    } else {
        $tray.Text = "Process Monitor - Running"
    }
})
$menu.Items.Add($menuMute) | Out-Null

$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null

$menuStop    = New-Object System.Windows.Forms.ToolStripMenuItem
$menuStop.Text = "Stop Monitor"
$menuStop.Add_Click({
    $script:Running = $false
    $tray.Icon = New-TrayIcon -Color "Red"
    $tray.Text = "Process Monitor - Stopping..."
})
$menu.Items.Add($menuStop) | Out-Null

$tray.ContextMenuStrip = $menu
$tray.Text = if ($script:Muted) { "Process Monitor - Running (muted)" } else { "Process Monitor - Running" }

# Double-click opens log folder too
$tray.Add_DoubleClick({ Start-Process explorer $LogDir })

# ── Startup banner ───────────────────────────────────────────
$banner = @"
============================================================
  ProcessMonitor started  $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  PID: $PID  |  Log folder: $LogDir
============================================================
"@
Write-Entry -Line $banner -IsError $false

# ── WMI Watcher ──────────────────────────────────────────────
$query   = "SELECT * FROM Win32_ProcessStopTrace"
$watcher = New-Object System.Management.ManagementEventWatcher
$watcher.Query   = New-Object System.Management.WqlEventQuery $query
$watcher.Options = New-Object System.Management.EventWatcherOptions
$watcher.Options.Timeout = [System.TimeSpan]::FromSeconds(2)

try {
    $watcher.Start()
} catch {
    Write-Entry -Line "[$(Get-Date -Format 'HH:mm:ss')] FATAL: Could not start WMI watcher - $_" -IsError $true
    $tray.Visible = $false
    $tray.Dispose()
    exit 1
}

# ── Main loop ────────────────────────────────────────────────
$script:Running = $true

while ($script:Running) {

    # Pump Windows messages so the tray icon stays responsive
    [System.Windows.Forms.Application]::DoEvents()

    # Check PID file - if Stop-Monitor.bat deleted it, exit
    if (-not (Test-Path $PidFile)) {
        Write-Entry -Line "[$(Get-Date -Format 'HH:mm:ss')] INFO  | PID file removed - shutting down." -IsError $false
        break
    }

    try {
        $evt  = $watcher.WaitForNextEvent()
        $data = $evt.Properties

        $procName  = $data["ProcessName"].Value
        $procPID   = $data["ProcessId"].Value
        $parentPID = $data["ParentProcessId"].Value
        $exitCode  = [uint32]$data["ExitStatus"].Value
        $timestamp = Get-Date -Format "HH:mm:ss"

        if ($SkipPIDs -contains $procPID)   { continue }
        if ($SkipNames -contains $procName) { continue }

        $isError = $exitCode -ne 0
        $tag     = if ($isError) { "ERROR " } else { "CLOSE " }
        $exitStr = Format-ExitCode -Code $exitCode

        # Try to identify the parent process (usually still alive at child exit)
        $parentTag = ""
        if ($parentPID -gt 0) {
            $parentProc = Get-Process -Id $parentPID -ErrorAction SilentlyContinue
            if ($parentProc) {
                $parentTag = "  [spawned by: $($parentProc.Name) ($parentPID)]"
            } else {
                $parentTag = "  [spawned by: ??? (PID $parentPID - already gone)]"
            }
        }

        $pidStr = $procPID.ToString().PadLeft(6)
        $extStr = $exitStr.PadRight(24)
        $line   = "[{0}] {1} | PID: {2} | Exit: {3} | {4}{5}" -f $timestamp, $tag, $pidStr, $extStr, $procName, $parentTag
        Write-Entry -Line $line -IsError $isError

        # Show a tray balloon on crashes (unless muted)
        if ($isError -and -not $script:Muted) {
            $tray.BalloonTipTitle = "Crash detected"
            $tray.BalloonTipText  = "$procName exited with $exitStr$parentTag"
            $tray.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Warning
            $tray.ShowBalloonTip(4000)
        }

    } catch [System.Management.ManagementException] {
        # Timeout - normal, just loop
        continue
    } catch {
        $errLine = "[$(Get-Date -Format 'HH:mm:ss')] WARN  | Watcher error: $_"
        Write-Entry -Line $errLine -IsError $false
        Start-Sleep -Seconds 2
    }
}

# ── Shutdown ─────────────────────────────────────────────────
$watcher.Stop()
$watcher.Dispose()

$tray.Visible = $false
$tray.Dispose()

$footer = "[$(Get-Date -Format 'HH:mm:ss')] INFO  | ProcessMonitor stopped."
Write-Entry -Line $footer -IsError $false

if (Test-Path $PidFile) { Remove-Item $PidFile -Force }
