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

# ── Known exit code descriptions ─────────────────────────────
# Keys are uppercase 8-digit hex strings (e.g. "0xC0000005") to avoid
# PS 5.1 signed/unsigned integer casting issues with [uint32] key syntax.
$script:ExitCodeTable = @{
    "0x00000001" = @{ Short="generic error";                Plain="The program exited with a generic failure code - no specific crash reason was recorded." }
    "0x00000002" = @{ Short="file not found";               Plain="The program could not find a file it needed. It may have been moved, deleted, or never installed." }
    "0x00000003" = @{ Short="path not found";               Plain="The program tried to access a folder that does not exist. A reinstall may fix this." }
    "0x00000005" = @{ Short="access denied";                Plain="The program was blocked from accessing a file or resource. Try running as administrator." }
    "0x00000102" = @{ Short="wait timeout";                 Plain="The program waited too long for something to respond (a server, a file, another process) and gave up." }
    "0xC0000005" = @{ Short="access violation";             Plain="The program tried to read or write memory it does not own. Usually a bug, bad mod/plugin, or driver conflict. A reinstall or update may help." }
    "0xC0000017" = @{ Short="out of memory";                Plain="The program ran out of memory. Try closing other applications, or your system may need more RAM." }
    "0xC000001D" = @{ Short="illegal instruction";          Plain="The program tried to execute an invalid CPU instruction. This can mean corrupt install files, hardware incompatibility, or overclocking instability." }
    "0xC000008E" = @{ Short="FP divide by zero";            Plain="The program tried to divide a decimal number by zero. This is a bug in the program." }
    "0xC0000094" = @{ Short="integer divide by zero";       Plain="The program tried to divide a whole number by zero. This is a bug in the program." }
    "0xC00000FD" = @{ Short="stack overflow";               Plain="The program ran out of stack space, usually from a function calling itself indefinitely. This is a bug in the program." }
    "0xC0000135" = @{ Short="DLL not found";                Plain="A required library file (.dll) is missing. Try reinstalling the program or installing the relevant runtime (e.g. Visual C++ Redistributable)." }
    "0xC0000142" = @{ Short="DLL init failed";              Plain="A required library loaded but failed to start. This can be caused by a corrupt install, a missing dependency, or an antivirus blocking it." }
    "0xC0000374" = @{ Short="heap corruption";              Plain="The program's memory was corrupted while it was running. Often caused by a bug, an incompatible mod or plugin, or a faulty RAM stick." }
    "0xC0000409" = @{ Short="stack buffer overrun";         Plain="The program wrote data past the end of a reserved memory area. This is a serious bug - if it keeps happening, check for malware or a bad update." }
    "0xC000041D" = @{ Short="unhandled callback exception"; Plain="An unhandled error occurred inside a Windows callback. Usually a bug in the program or an incompatible system component." }
    "0xC0000602" = @{ Short="fail fast exception";          Plain="The program detected a critical internal error and shut itself down on purpose. Check the program's own logs for details." }
    "0xE0434352" = @{ Short=".NET CLR exception";           Plain="An unhandled error occurred in a .NET application. Check the Windows Event Viewer (Application log) for the full error message and stack trace." }
    "0xCFFFFFFF" = @{ Short="game/custom crash code";       Plain="The game or program caught an internal error and exited with its own crash code. Check the game's own crash log or support site for details." }
}

function Get-ExitCodeKey  { param([uint32]$Code); return "0x{0:X8}" -f $Code }

function Get-ExitCodeDescription {
    param([uint32]$Code)
    $key = Get-ExitCodeKey $Code
    if ($script:ExitCodeTable.ContainsKey($key)) { return $script:ExitCodeTable[$key].Short }
    # 0xC0000000-0xCFFFFFFF = Windows NTSTATUS errors; 0xE0000000+ = user-defined
    if ($Code -ge 3221225472 -and $Code -le 3489660927) { return "unhandled exception" }
    if ($Code -ge 3758096384) { return "user-defined exception" }
    return $null
}

function Get-ExitCodePlain {
    param([uint32]$Code)
    $key = Get-ExitCodeKey $Code
    if ($script:ExitCodeTable.ContainsKey($key)) { return $script:ExitCodeTable[$key].Plain }
    if ($Code -ge 3221225472 -and $Code -le 3489660927) { return "An unhandled Windows exception caused the program to crash." }
    if ($Code -ge 3758096384) { return "The program exited with a user-defined exception code. Check the program's own logs for details." }
    return $null
}

function Get-WerCrashDetail {
    param([string]$ProcessName, [datetime]$CrashTime)
    try {
        # Give Windows Error Reporting a moment to write the event
        Start-Sleep -Milliseconds 1000
        $events = Get-WinEvent -FilterHashtable @{
            LogName   = 'Application'
            Id        = 1000
            StartTime = $CrashTime.AddSeconds(-5)
        } -MaxEvents 20 -ErrorAction SilentlyContinue
        if (-not $events) { return $null }

        $baseName = $ProcessName -replace '\.exe$', ''
        $evt = $events | Where-Object {
            $_.Message -match [regex]::Escape($ProcessName) -or
            $_.Message -match [regex]::Escape($baseName)
        } | Select-Object -First 1
        if (-not $evt) { return $null }

        $msg    = $evt.Message
        $module = if ($msg -match 'Faulting module name:\s*([^,\r\n]+)') { $Matches[1].Trim() } else { $null }
        $exc    = if ($msg -match 'Exception code:\s*(0x[0-9A-Fa-f]+)')  { $Matches[1].Trim() } else { $null }

        $parts = @()
        if ($module) { $parts += "module: $module" }
        if ($exc)    { $parts += "exception: $exc" }
        if ($parts.Count -gt 0) { return ($parts -join " | ") }
        return $null
    }
    catch { return $null }
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
        $evt = $watcher.WaitForNextEvent()
        if ($null -eq $evt) { continue }

        $data      = $evt.Properties
        $procName  = if ($data["ProcessName"])    { $data["ProcessName"].Value }    else { $null }
        $procPID   = if ($data["ProcessId"])      { $data["ProcessId"].Value }      else { $null }
        $parentPID = if ($data["ParentProcessId"]){ $data["ParentProcessId"].Value } else { 0 }
        $exitCode  = if ($data["ExitStatus"])     { [uint32]$data["ExitStatus"].Value } else { 0 }

        if ($null -eq $procName -or $null -eq $procPID) { continue }
        $timestamp = Get-Date -Format "HH:mm:ss"

        if ($SkipPIDs -contains $procPID)   { continue }
        if ($SkipNames -contains $procName) { continue }

        $isError = $exitCode -ne 0
        if (-not $isError) { continue }   # ignore clean exits

        $tag = "ERROR "
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

        # Build crash context tag and plain-language explanation for error exits
        $crashTag  = ""
        $plainDesc = ""
        if ($isError) {
            $desc      = Get-ExitCodeDescription -Code $exitCode
            $plainDesc = Get-ExitCodePlain       -Code $exitCode
            $wer       = Get-WerCrashDetail -ProcessName $procName -CrashTime (Get-Date)
            $parts     = @()
            if ($desc) { $parts += $desc }
            if ($wer)  { $parts += $wer }
            if ($parts) { $crashTag = "  [crash: $($parts -join ' | ')]" }
        }

        $pidStr = $procPID.ToString().PadLeft(6)
        $extStr = $exitStr.PadRight(24)
        $line   = "[{0}] {1} | PID: {2} | Exit: {3} | {4}{5}{6}" -f $timestamp, $tag, $pidStr, $extStr, $procName, $parentTag, $crashTag
        Write-Entry -Line $line -IsError $isError

        # Write plain-language explanation on the next line for crashes
        if ($isError -and $plainDesc) {
            Write-Entry -Line "           why --> $plainDesc" -IsError $true
        }

        # Show a tray balloon on crashes (unless muted)
        if ($isError -and -not $script:Muted) {
            $tray.BalloonTipTitle = "Crash: $procName"
            $tray.BalloonTipText  = if ($plainDesc) { $plainDesc } else { "$procName exited with $exitStr" }
            $tray.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Warning
            $tray.ShowBalloonTip(5000)
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
