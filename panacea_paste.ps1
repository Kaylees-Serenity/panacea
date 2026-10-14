$panacea = @'
#requires -version 5.1
<#
    ℞ PANACEA — the universal remedy
    DIAGNOSE tier : preflight gate + color engine + Rx banner
    Native-only · non-interactive · fails-closed · single-paste
    Run from a remote-support shell as SYSTEM, or an elevated admin prompt.
#>

# ═══════════════════════════════════════════════════════════════
#  CONFIG BLOCK  —  every behavior decision lives here, up top
# ═══════════════════════════════════════════════════════════════
$Panacea = [ordered]@{
    Version        = '1.0'
    NoColor        = $false        # force ASCII/no-VT skin
    MinFreeGB      = 15            # DIAGNOSE bails below this
    MaxCpuPct      = 70            # "spare performance" gate
    MaxRamPct      = 90            # bail if memory already pegged
    RebootPolicy   = 'warn'        # 'warn' = flag & proceed · 'stop' = halt if pending
    LogRoot        = "$env:ProgramData\Panacea\TuneUp"
    DryRun         = $false        # rehearsal mode: report what WOULD happen, mutate nothing
    PromptDose     = $true         # if interactive, ask before administering updates
    RunWinSxS      = $true         # run DISM StartComponentCleanup during PURGE
    ShowSetup      = $true         # show the interactive configure panel before DIAGNOSE
    DisableFastBoot = $false       # turn off Windows Fast Startup (HiberbootEnabled=0) during TONIC
    # long-running operation ceilings (seconds) — 0 = infinite (default; rely on Windows).
    # slow boxes are the norm; the S-key still gives instant bail on any long op.
    DismCheckTimeoutSec   = 0
    DismScanTimeoutSec    = 0
    DismRestoreTimeoutSec = 0
    SfcTimeoutSec         = 0
    VendorTimeoutSec      = 0
    WinSxSTimeoutSec      = 0
    # the one ceiling that is NOT infinite: a Windows Update download that has not
    # finished in two hours is stuck, not slow. Panacea stops waiting, installs
    # nothing, and points at ALKAHEST. independent of the [4] Timeouts cycle.
    WuDownloadTimeoutSec  = 7200
}

# ═══════════════════════════════════════════════════════════════
#  COLOR ENGINE  —  VT-sniff, truecolor, ASCII fallback
# ═══════════════════════════════════════════════════════════════
$script:VT = $false
if (-not $Panacea.NoColor) {
    try {
        # VT processing is reliable on PS7+, and on 5.1 when the host reports it.
        if ($PSVersionTable.PSVersion.Major -ge 7) { $script:VT = $true }
        elseif ($Host.UI.SupportsVirtualTerminal) { $script:VT = $true }
    } catch { $script:VT = $false }
}
$e = [char]27
function Paint {
    param([string]$Text,[int[]]$Fg,[int[]]$Bg)
    if (-not $script:VT) { return $Text }
    $seq = ''
    if ($Fg) { $seq += "$e[38;2;$($Fg[0]);$($Fg[1]);$($Fg[2])m" }
    if ($Bg) { $seq += "$e[48;2;$($Bg[0]);$($Bg[1]);$($Bg[2])m" }
    "$seq$Text$e[0m"
}
# Panacea palette
$Clr = @{
    Orange = @(255,140,0)   # Rx warning
    Green  = @(80,200,120)  # cured / healthy
    Cyan   = @(90,190,220)  # administering / fixed
    Grey   = @(120,120,120) # dim frame / skipped
    Red    = @(220,50,50)   # failed
    Black  = @(0,0,0)
}
# Glyph language — VT gets the pretty ones, ASCII skin degrades gracefully
if ($script:VT) {
    $G = @{ Ok='[✓]'; Work='[»]'; Warn='[!]'; Fail='[✗]'; Skip='[~]'; Rx='℞'; Staff='⚕'; Bell='⚠' }
} else {
    $G = @{ Ok='[OK]'; Work='[>>]'; Warn='[!]'; Fail='[XX]'; Skip='[~]'; Rx='Rx'; Staff='+'; Bell='!!' }
}

# ═══════════════════════════════════════════════════════════════
#  RESULT LEDGER  —  every tier writes here; PROGNOSIS reads it
# ═══════════════════════════════════════════════════════════════
try { $ctxName = [Security.Principal.WindowsIdentity]::GetCurrent().Name } catch { $ctxName = 'unknown' }
$script:Ledger = [ordered]@{
    Host        = $env:COMPUTERNAME
    Session     = -join ((48..57)+(97..102) | Get-Random -Count 6 | ForEach-Object {[char]$_})
    Started     = Get-Date
    Context     = $ctxName
    OSBuild     = ''
    UptimeDays  = 0
    UptimeText  = ''
    FreeGBBefore = 0.0
    FreeGBAfter  = 0.0
    JoinType    = ''
    AdDomain    = ''
    AadTenant   = ''
    MdmEnrolled = $false
    Warnings    = New-Object System.Collections.Generic.List[string]
    Symptoms    = New-Object System.Collections.Generic.List[string]
    Proceed     = $true
}

function Rule($label) {
    $line = ('─' * 62)
    if (-not $script:VT) { $line = ('-' * 62) }
    Write-Host ''
    $suffix = if ($Panacea.DryRun) { ' [DRY RUN]' } else { '' }
    Write-Host (Paint "── $label$suffix $line" -Fg $Clr.Cyan)
}
function Status {
    param([string]$Glyph,[string]$Label,[string]$Value,[int[]]$Color=$Clr.Grey)
    $g = Paint $Glyph -Fg $Color
    $dots = '.' * [Math]::Max(3, 20 - $Label.Length)
    Write-Host "   $g $Label $dots $Value"
}

# ═══════════════════════════════════════════════════════════════
#  BANNER  —  big wordmark into the Rx label frame
# ═══════════════════════════════════════════════════════════════
function Show-Banner {
    $wm = @(
        '   ██████╗  █████╗ ███╗   ██╗ █████╗  ██████╗███████╗ █████╗',
        '   ██╔══██╗██╔══██╗████╗  ██║██╔══██╗██╔════╝██╔════╝██╔══██╗',
        '   ██████╔╝███████║██╔██╗ ██║███████║██║     █████╗  ███████║',
        '   ██╔═══╝ ██╔══██║██║╚██╗██║██╔══██║██║     ██╔══╝  ██╔══██║',
        '   ██║     ██║  ██║██║ ╚████║██║  ██║╚██████╗███████╗██║  ██║',
        '   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝  ╚═╝'
    ) -join "`n"
    $bar = '═' * 62; $mid = '─' * 62
    if (-not $script:VT) { $bar = '=' * 62; $mid = '-' * 62 }
    Write-Host (Paint "╔$bar╗" -Fg $Clr.Cyan)
    foreach ($ln in $wm -split "`n") { Write-Host (Paint $ln -Fg $Clr.Green) }
    Write-Host ''
    Write-Host (Paint "   $($G.Rx)  THE UNIVERSAL REMEDY  ·  apothecary systems  ·  v$($Panacea.Version)" -Fg $Clr.Cyan)
    Write-Host (Paint "╟$mid╢" -Fg $Clr.Grey)
    $d = Get-Date -Format 'yyyy-MM-dd HH:mm'
    Write-Host (Paint "  RX # $($script:Ledger.Session.ToUpper())" -Fg $Clr.Grey) -NoNewline
    $inf = if ($script:VT) { [char]0x221E } else { 'unlimited' }
    Write-Host (Paint "            DATE: $d    REFILLS: $inf" -Fg $Clr.Grey)
    Write-Host (Paint "  PATIENT: $($script:Ledger.Host)" -Fg $Clr.Grey)
    Write-Host (Paint "  PRESCRIBER: $($script:Ledger.Context)" -Fg $Clr.Grey)
    Write-Host (Paint "  DX: $($script:Ledger.OSBuild)" -Fg $Clr.Grey)
    Write-Host (Paint "╚$bar╝" -Fg $Clr.Cyan)
}

# ═══════════════════════════════════════════════════════════════
#  SETUP  —  interactive configure panel before infusion begins.
#             non-interactive contexts (SYSTEM/remote shell) skip it.
# ═══════════════════════════════════════════════════════════════
$script:PanaceaAbort = $false
function Show-Setup {
    if (-not $Panacea.ShowSetup) { return }
    $interactive = $false
    try { $interactive = -not [Console]::IsInputRedirected } catch { $interactive = $false }
    if (-not $interactive) { return }

    $inf = if ($script:VT) { [char]0x221E } else { 'unlimited' }
    while ($true) {
        $bar = '─' * 62
        if (-not $script:VT) { $bar = '-' * 62 }
        Write-Host ''
        Write-Host (Paint "── DISPENSARY SETUP $bar" -Fg $Clr.Cyan)
        Write-Host (Paint "   configure before infusion begins · each line shows what will happen" -Fg $Clr.Grey)
        Write-Host ''

        # state-aware: each hint describes what the CURRENT state will do
        if ($Panacea.DryRun) {
            $dryV = 'ON '; $dryHint = 'will only pretend — no changes made'
        } else {
            $dryV = 'OFF'; $dryHint = 'will make real changes when run'
        }
        if ($Panacea.PromptDose) {
            $prmV = 'ON '; $prmHint = 'will ask before installing updates'
        } else {
            $prmV = 'OFF'; $prmHint = 'will install updates without asking'
        }
        if ($Panacea.RunWinSxS) {
            $wsxV = 'ON '; $wsxHint = 'will trim Windows component store'
        } else {
            $wsxV = 'OFF'; $wsxHint = 'will skip component store cleanup'
        }
        if ($Panacea.DismRestoreTimeoutSec -eq 0) {
            $toV = "$inf   "; $toHint = 'no time limit — best for slow PCs'
        } else {
            $mins = [Math]::Round($Panacea.DismRestoreTimeoutSec/60)
            $toV = "{0,-4}m" -f $mins
            $toHint = "kills stuck operations after $mins min"
        }
        if ($Panacea.DisableFastBoot) {
            $fbV = 'ON '; $fbHint = 'will turn off Windows Fast Startup'
        } else {
            $fbV = 'OFF'; $fbHint = 'will leave Fast Startup as it is'
        }
        $rbV = "{0,-4}" -f $Panacea.RebootPolicy
        if ($Panacea.RebootPolicy -eq 'warn') {
            $rbHint = 'runs even if reboot is already pending'
        } else {
            $rbHint = 'halts if reboot is already pending'
        }

        Write-Host (Paint "   [1] DryRun ............ $dryV   $dryHint" -Fg $Clr.Grey)
        Write-Host (Paint "   [2] Prompt DOSE ....... $prmV   $prmHint" -Fg $Clr.Grey)
        Write-Host (Paint "   [3] WinSxS cleanup .... $wsxV   $wsxHint" -Fg $Clr.Grey)
        Write-Host (Paint "   [4] Timeouts .......... $toV  $toHint" -Fg $Clr.Grey)
        Write-Host (Paint "   [5] Reboot policy ..... $rbV  $rbHint" -Fg $Clr.Grey)
        Write-Host (Paint "   [6] Disable fast boot . $fbV   $fbHint" -Fg $Clr.Grey)
        Write-Host ''
        Write-Host (Paint "   [Enter] proceed  ·  [Q] quit" -Fg $Clr.Cyan)
        Write-Host (Paint "    > " -Fg $Clr.Cyan) -NoNewline
        $c = [Console]::ReadLine()
        if ($null -eq $c) { return }
        $c = $c.Trim()

        if ($c -eq '') { return }                              # Enter → proceed
        elseif ($c -match '^[Qq]') {
            Write-Host ''
            Write-Host (Paint "   dispensary closed  ·  aborted at setup — nothing touched" -Fg $Clr.Grey)
            $script:PanaceaAbort = $true
            return
        }
        elseif ($c -eq '1') { $Panacea.DryRun     = -not $Panacea.DryRun }
        elseif ($c -eq '2') { $Panacea.PromptDose = -not $Panacea.PromptDose }
        elseif ($c -eq '3') { $Panacea.RunWinSxS  = -not $Panacea.RunWinSxS }
        elseif ($c -eq '4') {
            # cycle: ∞ → 30min → 60min → ∞
            if ($Panacea.DismRestoreTimeoutSec -eq 0) {
                $Panacea.DismCheckTimeoutSec   = 300
                $Panacea.DismScanTimeoutSec    = 1800
                $Panacea.DismRestoreTimeoutSec = 1800
                $Panacea.SfcTimeoutSec         = 1800
                $Panacea.VendorTimeoutSec      = 1800
                $Panacea.WinSxSTimeoutSec      = 1800
            } elseif ($Panacea.DismRestoreTimeoutSec -le 1800) {
                $Panacea.DismCheckTimeoutSec   = 600
                $Panacea.DismScanTimeoutSec    = 3600
                $Panacea.DismRestoreTimeoutSec = 3600
                $Panacea.SfcTimeoutSec         = 3600
                $Panacea.VendorTimeoutSec      = 3600
                $Panacea.WinSxSTimeoutSec      = 3600
            } else {
                $Panacea.DismCheckTimeoutSec   = 0
                $Panacea.DismScanTimeoutSec    = 0
                $Panacea.DismRestoreTimeoutSec = 0
                $Panacea.SfcTimeoutSec         = 0
                $Panacea.VendorTimeoutSec      = 0
                $Panacea.WinSxSTimeoutSec      = 0
            }
        }
        elseif ($c -eq '5') {
            $Panacea.RebootPolicy = if ($Panacea.RebootPolicy -eq 'warn') { 'stop' } else { 'warn' }
        }
        elseif ($c -eq '6') { $Panacea.DisableFastBoot = -not $Panacea.DisableFastBoot }
        # anything else: silently redraw
    }
}

# ═══════════════════════════════════════════════════════════════
#  DIAGNOSE  —  the preflight gate. bail fast, bail loud.
# ═══════════════════════════════════════════════════════════════

# OS build first so the banner DX line is populated before we print it
try {
    $os  = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cv  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    $disp = if ($cv.DisplayVersion) { $cv.DisplayVersion } else { $cv.ReleaseId }
    $script:Ledger.OSBuild = "$($os.Caption.Replace('Microsoft ','')) $disp (build $($cv.CurrentBuildNumber).$($cv.UBR))"
} catch { $script:Ledger.OSBuild = 'Windows (build detection failed)' }

Show-Banner
Show-Setup
if ($script:PanaceaAbort) { $global:PanaceaExit = 0; return }

# open the transcript BEFORE the gate so halted runs get logged too
$script:LogFile = $null
try {
    if (-not (Test-Path $Panacea.LogRoot)) { New-Item -ItemType Directory -Path $Panacea.LogRoot -Force | Out-Null }
    $script:LogFile = Join-Path $Panacea.LogRoot ("panacea_{0}_{1}.log" -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd_HHmmss'))
    Start-Transcript -Path $script:LogFile -Append -ErrorAction SilentlyContinue | Out-Null
} catch { $script:LogFile = $null }

Rule 'DIAGNOSE'

# 1 — elevation / context
try {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch { $isAdmin = $false }
$isSystem = $script:Ledger.Context -eq 'NT AUTHORITY\SYSTEM'
if ($isSystem)      { Status $G.Ok  'elevation' 'SYSTEM' $Clr.Green }
elseif ($isAdmin)   { Status $G.Ok  'elevation' 'Administrator' $Clr.Green }
else {
    Status $G.Fail 'elevation' 'NOT elevated — cannot proceed' $Clr.Red
    $script:Ledger.Proceed = $false
    $script:Ledger.Symptoms.Add('not run as admin/SYSTEM')
}

# 2 — disk headroom on the system drive
try {
    $sys = ($env:SystemDrive)
    $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sys'" -ErrorAction Stop
    $freeGB = [Math]::Round($vol.FreeSpace/1GB,1)
    if ($freeGB -ge $Panacea.MinFreeGB) {
        Status $G.Ok 'disk headroom' "$freeGB GB free" $Clr.Green
    } else {
        Status $G.Warn 'disk headroom' "$freeGB GB — below $($Panacea.MinFreeGB)GB floor" $Clr.Orange
        $script:Ledger.Symptoms.Add("low disk: $freeGB GB free")
        # low disk is a symptom, not a hard stop — PURGE might be the whole cure
    }
} catch { Status $G.Skip 'disk headroom' 'unreadable' $Clr.Grey }

# 3 — pending reboot (detect + report source; policy decides stop-vs-warn)
$rbSources = @()
$rbKeys = @(
    @{ P='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'; N='CBS' },
    @{ P='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'; N='WindowsUpdate' }
)
foreach ($k in $rbKeys) { if (Test-Path $k.P) { $rbSources += $k.N } }
try {
    $pfro = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
    if ($pfro.PendingFileRenameOperations) { $rbSources += 'PendingFileRename' }
} catch {}
if ($rbSources.Count -gt 0) {
    $src = $rbSources -join ' + '
    if ($Panacea.RebootPolicy -eq 'stop') {
        Status $G.Fail 'pending reboot' "$src — halting (policy=stop)" $Clr.Red
        $script:Ledger.Proceed = $false
    } else {
        Status $G.Warn 'pending reboot' "$src → will flag at end" $Clr.Orange
    }
    $script:Ledger.Warnings.Add("reboot pending before run ($src)")
} else {
    Status $G.Ok 'pending reboot' 'none' $Clr.Green
}

# 4 — resource sanity ("spare performance" gate)
try {
    $cpu = [Math]::Round((Get-CimInstance Win32_Processor -ErrorAction Stop |
            Measure-Object -Property LoadPercentage -Average).Average)
    $ramPct = [Math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) /
              $os.TotalVisibleMemorySize * 100)
    if ($cpu -le $Panacea.MaxCpuPct -and $ramPct -le $Panacea.MaxRamPct) {
        Status $G.Ok 'resource load' "CPU $cpu% · RAM $ramPct% → clear" $Clr.Green
    } else {
        Status $G.Warn 'resource load' "CPU $cpu% · RAM $ramPct% → box is busy" $Clr.Orange
        $script:Ledger.Symptoms.Add("high load at start: CPU $cpu% RAM $ramPct%")
    }
} catch { Status $G.Skip 'resource load' 'unreadable' $Clr.Grey }

# 5 — power state (skip cleanly on desktops)
try {
    $batt = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($batt) {
        # Win32_Battery.BatteryStatus enum:
        #   1=Discharging, 4=Low, 5=Critical → clearly on battery
        #   2=AC (not charging), 3=Fully Charged, 6-9=Charging variants, 11=Partially Charged → on AC
        if ($batt.BatteryStatus -in @(1,4,5)) {
            Status $G.Warn 'power' 'ON BATTERY — plug in before long ops' $Clr.Orange
            $script:Ledger.Warnings.Add('running on battery')
        } else {
            Status $G.Ok 'power' 'on AC' $Clr.Green
        }
    } else { Status $G.Ok 'power' 'desktop (no battery)' $Clr.Green }
} catch { Status $G.Skip 'power' 'unreadable' $Clr.Grey }

# 6 — VITALS: uptime + free-space baseline (captured now, delta rendered at end)
try {
    # Get-CimInstance returns LastBootUpTime as a native [datetime] already —
    # ConvertToDateTime() is the old WMI-era method and throws on CimInstance objects.
    $up = (Get-Date) - [datetime]$os.LastBootUpTime
    $script:Ledger.UptimeDays = [int]$up.TotalDays
    if     ($up.TotalDays -ge 1) { $script:Ledger.UptimeText = "{0}d {1}h" -f [int]$up.TotalDays, $up.Hours }
    elseif ($up.TotalHours -ge 1) { $script:Ledger.UptimeText = "{0}h {1}m" -f [int]$up.TotalHours, $up.Minutes }
    else                          { $script:Ledger.UptimeText = "{0}m"      -f [int]$up.TotalMinutes }
    # long uptime is a symptom on client boxes — flag but don't halt
    if ($up.TotalDays -ge 14) {
        Status $G.Warn 'vitals' ("uptime " + $script:Ledger.UptimeText + " — long uptime, reboot overdue") $Clr.Orange
        $script:Ledger.Warnings.Add("long uptime: " + $script:Ledger.UptimeText)
    } else {
        Status $G.Ok 'vitals' ("uptime " + $script:Ledger.UptimeText) $Clr.Green
    }
} catch { Status $G.Skip 'vitals' 'uptime unreadable' $Clr.Grey }

# capture free-space baseline for delta at PROGNOSIS (already read $freeGB above)
try { $script:Ledger.FreeGBBefore = [double]$freeGB } catch { $script:Ledger.FreeGBBefore = 0.0 }

# 7 — identity: domain / Azure AD / hybrid / Intune enrollment state
# native — dsregcmd ships in every Win10/11 build, works under SYSTEM, no install
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $adJoined  = [bool]$cs.PartOfDomain
    $adDomain  = if ($adJoined) { $cs.Domain } else { $null }

    $aadJoined  = $false
    $aadTenant  = ''
    $mdmEnrolled = $false
    $wpj = $false
    try {
        $dsreg = & "$env:SystemRoot\System32\dsregcmd.exe" /status 2>$null
        $dsregText = ($dsreg -join "`n")
        if ($dsregText -match 'AzureAdJoined\s*:\s*YES')    { $aadJoined = $true }
        if ($dsregText -match 'WorkplaceJoined\s*:\s*YES')  { $wpj = $true }
        if ($dsregText -match 'MdmUrl\s*:\s*http')          { $mdmEnrolled = $true }
        if ($dsregText -match 'TenantName\s*:\s*(.+)')      { $aadTenant = $Matches[1].Trim() }
    } catch {}

    $joinType =
        if     ($aadJoined -and $adJoined) { 'Hybrid-joined' }
        elseif ($aadJoined)                { 'Azure AD-joined' }
        elseif ($adJoined)                 { 'AD-joined' }
        elseif ($wpj)                      { 'Azure AD Registered' }
        else                               { 'Workgroup' }

    $bits = @($joinType)
    if ($adDomain)                   { $bits += $adDomain }
    if ($aadTenant -and $aadJoined)  { $bits += $aadTenant }
    if ($mdmEnrolled)                { $bits += 'Intune-enrolled' }
    $identText = $bits -join ' · '

    # workgroup is a legitimate but "nothing to see here" state — grey, not green
    if ($joinType -eq 'Workgroup') {
        Status $G.Skip 'identity' $identText $Clr.Grey
    } else {
        Status $G.Ok 'identity' $identText $Clr.Green
    }

    $script:Ledger.JoinType    = $joinType
    $script:Ledger.AdDomain    = $adDomain
    $script:Ledger.AadTenant   = $aadTenant
    $script:Ledger.MdmEnrolled = $mdmEnrolled
} catch { Status $G.Skip 'identity' 'unreadable' $Clr.Grey }

# ── gate verdict ────────────────────────────────────────────────
if (-not $script:Ledger.Proceed) {
    Write-Host ''
    if ($script:VT) {
        Write-Host (Paint "  $($G.Bell) DIAGNOSE HALTED — $($script:Ledger.Symptoms -join '; ') " -Fg $Clr.Black -Bg $Clr.Orange)
    } else {
        Write-Host "  !! DIAGNOSE HALTED — $($script:Ledger.Symptoms -join '; ') !!"
    }
    Write-Host ''
    $global:PanaceaExit = 2
    $exitVal = $global:PanaceaExit
    $logPath = $script:LogFile
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
    Write-Host (Paint "   dispensary closed  ·  `$PanaceaExit = $exitVal  ·  log: $logPath" -Fg $Clr.Grey)
    return   # <-- hard stop inside the scriptblock; MEND/DOSE/PURGE never run. does NOT kill the host.
}
Write-Host ''
Write-Host (Paint "   diagnosis complete — cleared to proceed" -Fg $Clr.Green)

# helper: run a native exe with a timeout so a hung process never strands the remote shell
function Invoke-Guarded {
    param(
        [string]$File,
        [string]$Arguments,
        [int]$TimeoutSec = 1800,
        [string]$Label = '',
        [switch]$ShowNative   # let stdout flow to console (native DISM/SFC progress bar)
    )
    $canSkip = $false
    try { $canSkip = -not [Console]::IsInputRedirected } catch { $canSkip = $false }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $File
    $psi.Arguments = $Arguments
    $psi.UseShellExecute = $false
    if ($ShowNative) {
        # stdout inherits parent console → DISM/SFC print their own progress bar in place
        $psi.RedirectStandardOutput = $false
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow = $false
    } else {
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.CreateNoWindow = $true
    }
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    $sbOut = New-Object System.Text.StringBuilder
    $sbErr = New-Object System.Text.StringBuilder

    if (-not $ShowNative) {
        $outEvt = Register-ObjectEvent -InputObject $p -EventName OutputDataReceived -Action {
            if ($EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) }
        } -MessageData $sbOut
    }
    $errEvt = Register-ObjectEvent -InputObject $p -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) { [void]$Event.MessageData.AppendLine($EventArgs.Data) }
    } -MessageData $sbErr

    # tell the user skip is armed BEFORE the tool starts spamming the console
    if ($ShowNative -and $canSkip) {
        Write-Host (Paint "      (press S at any time to skip)" -Fg $Clr.Grey)
    }

    $code = -1; $skipped = $false; $timedOut = $false
    try {
        [void]$p.Start()
        if (-not $ShowNative) { $p.BeginOutputReadLine() }
        $p.BeginErrorReadLine()

        # spinner glyphs — only used in non-native mode where we render our own heartbeat
        if ($script:VT) { $frames = @([char]0x280B,[char]0x2819,[char]0x2839,[char]0x2838,[char]0x283C,[char]0x2834,[char]0x2826,[char]0x2827,[char]0x2807,[char]0x280F) }
        else            { $frames = @('|','/','-','\') }

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $frameIdx = 0

        while (-not $p.HasExited) {
            # timeout ceiling — 0 or negative means infinite (rely on native Windows failures)
            if ($TimeoutSec -gt 0 -and $sw.Elapsed.TotalSeconds -ge $TimeoutSec) { $timedOut = $true; try { $p.Kill() } catch {}; break }
            if ($canSkip) {
                try {
                    if ([Console]::KeyAvailable) {
                        $k = [Console]::ReadKey($true)
                        if ($k.KeyChar -eq 's' -or $k.KeyChar -eq 'S') {
                            $skipped = $true
                            try { $p.Kill() } catch {}
                            break
                        }
                    }
                } catch {}
            }
            # native mode: DISM/SFC own the display, we stay quiet
            # redirected mode: paint our own heartbeat line
            if (-not $ShowNative) {
                $elapsed = "{0:mm\:ss}" -f $sw.Elapsed
                $spin = $frames[$frameIdx % $frames.Count]
                $hint = if ($canSkip) { 'press S to skip' } else { 'running' }
                $lbl  = if ($Label) { $Label } else { 'working' }
                $line = "      $spin  $lbl  ·  $elapsed elapsed  ·  $hint"
                try { [Console]::Write("`r" + $line.PadRight(70)) } catch {}
                $frameIdx++
            }
            Start-Sleep -Milliseconds 250
        }
        if (-not $ShowNative) {
            try { [Console]::Write("`r" + (' ' * 72) + "`r") } catch {}
        } else {
            # DISM/SFC leave the cursor wherever their last \r update sat — bump to a fresh line
            Write-Host ''
        }

        Start-Sleep -Milliseconds 200
        $code = if ($skipped -or $timedOut) { -1 } else { try { $p.ExitCode } catch { -1 } }
    }
    finally {
        # unregister ALWAYS — even if the loop threw — so no orphan subscriptions
        # outlive the scriptblock and pollute the parent runspace
        if (-not $ShowNative -and $outEvt) {
            Unregister-Event -SourceIdentifier $outEvt.Name -ErrorAction SilentlyContinue
            Remove-Job -Job $outEvt -Force -ErrorAction SilentlyContinue
        }
        if ($errEvt) {
            Unregister-Event -SourceIdentifier $errEvt.Name -ErrorAction SilentlyContinue
            Remove-Job -Job $errEvt -Force -ErrorAction SilentlyContinue
        }
        try { if (-not $p.HasExited) { $p.Kill() } } catch {}
        try { $p.Dispose() } catch {}
    }

    [pscustomobject]@{
        ExitCode = $code
        TimedOut = $timedOut
        Skipped  = $skipped
        StdOut   = $sbOut.ToString()
        StdErr   = $sbErr.ToString()
    }
}

# ═══════════════════════════════════════════════════════════════
#  WU RUNNER  —  Windows Update search/download/install on a worker
#               thread, so a stuck download can be walked away from
# ═══════════════════════════════════════════════════════════════
# WUA's Download() blocks until Windows Update gives up, which on a wedged
# stack is never. BeginDownload would fix that but needs a compiled COM
# callback (Add-Type → csc.exe, an EDR-flagged LOLBin), so the plain calls run
# in their own runspace and this thread watches the clock instead. Every WUA
# object is created and used on that one worker thread; no COM crosses threads.
# Same contract as Invoke-Guarded: S skips, a ceiling of 0 means infinite.
# Mode: 'search' (report only) · 'download' (stage, no install) · 'install'
function Invoke-WuPipeline {
    param(
        [ValidateSet('search','download','install')][string]$Mode = 'install',
        [int]$DownloadTimeoutSec = 7200,
        [string]$Label = 'windows update'
    )
    $state = [hashtable]::Synchronized(@{
        Phase = 'search'; PhaseStarted = [DateTime]::UtcNow; Abandon = $false
        SearchMs = 0; Found = @(); Downloaded = @(); Failed = @()
        InstallCode = -1; RebootRequired = $false; Error = $null
    })

    $work = {
        param($state, $mode)
        # phase change and the watcher's abandon decision share one lock, so the
        # worker can never start installing in the gap after the watcher gave up
        function Enter-Phase($name) {
            [System.Threading.Monitor]::Enter($state.SyncRoot)
            try {
                if ($state.Abandon) { return $false }
                $state.Phase = $name; $state.PhaseStarted = [DateTime]::UtcNow
                return $true
            } finally { [System.Threading.Monitor]::Exit($state.SyncRoot) }
        }
        try {
            $session  = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            # IsInstalled=0, software type, not hidden. Drivers & feature-upgrades fenced off by default.
            $res = $searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
            $sw.Stop(); $state.SearchMs = [int]$sw.ElapsedMilliseconds

            $coll = New-Object -ComObject Microsoft.Update.UpdateColl
            $kbs  = @()
            foreach ($u in $res.Updates) {
                # hard-exclude feature/upgrade packages — a paste tool never rides a build upgrade
                if ($u.Title -match 'Feature update|Upgrade to Windows|\b2[0-9]H[12]\b') { continue }
                [void]$coll.Add($u)
                $kb = ($u.KBArticleIDs | ForEach-Object { "KB$_" }) -join ','
                if (-not $kb) { $kb = '(no KB)' }
                $kbs += $kb
            }
            $state.Found = $kbs
            if ($mode -eq 'search' -or $coll.Count -eq 0) { return }

            if (-not (Enter-Phase 'download')) { return }
            $dl = $session.CreateUpdateDownloader(); $dl.Updates = $coll
            $dlRes = $dl.Download()

            # read every update's own verdict — the batch code can say "succeeded"
            # with half the payloads missing, and installing those is what wedges
            $ready = New-Object -ComObject Microsoft.Update.UpdateColl
            $okKbs = @(); $badKbs = @()
            for ($i = 0; $i -lt $coll.Count; $i++) {
                $u = $coll.Item($i)
                $r = $dlRes.GetUpdateResult($i)
                # ResultCode 2 = succeeded, 3 = succeeded w/ errors
                if ($r.ResultCode -eq 2 -or $r.ResultCode -eq 3 -or $u.IsDownloaded) {
                    [void]$ready.Add($u); $okKbs += $kbs[$i]
                } else {
                    $badKbs += ('{0} (0x{1:X8})' -f $kbs[$i], $r.HResult)
                }
            }
            $state.Downloaded = $okKbs; $state.Failed = $badKbs
            if ($mode -eq 'download' -or $ready.Count -eq 0) { return }

            if (-not (Enter-Phase 'install')) { return }
            # install (reboot suppressed — WUA won't force restart from here)
            $inst = $session.CreateUpdateInstaller(); $inst.Updates = $ready
            $instRes = $inst.Install()
            $state.InstallCode    = [int]$instRes.ResultCode
            $state.RebootRequired = [bool]$instRes.RebootRequired
        } catch {
            $state.Error = $_.Exception.Message.Split("`n")[0]
        }
    }

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'          # the apartment the console thread gave WUA before
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddScript($work.ToString()).AddArgument($state).AddArgument($Mode)
    $handle = $ps.BeginInvoke()

    $canSkip = $false
    try { $canSkip = -not [Console]::IsInputRedirected } catch { $canSkip = $false }
    if ($script:VT) { $frames = @([char]0x280B,[char]0x2819,[char]0x2839,[char]0x2838,[char]0x283C,[char]0x2834,[char]0x2826,[char]0x2827,[char]0x2807,[char]0x280F) }
    else            { $frames = @('|','/','-','\') }
    $frameIdx = 0; $seen = 'search'; $outcome = 'done'

    while (-not $handle.IsCompleted) {
        $phase = $state.Phase
        if ($phase -ne $seen) {
            try { [Console]::Write("`r" + (' ' * 72) + "`r") } catch {}
            if ($phase -eq 'download') { Status $G.Work $Label "$($state.Found.Count) found → downloading..." $Clr.Cyan }
            if ($phase -eq 'install')  { Status $G.Work $Label "$($state.Downloaded.Count) downloaded → installing (reboot suppressed)..." $Clr.Cyan }
            $seen = $phase
        }
        $inPhase = [DateTime]::UtcNow - $state.PhaseStarted

        $giveUp = $null
        if ($phase -eq 'download' -and $DownloadTimeoutSec -gt 0 -and $inPhase.TotalSeconds -ge $DownloadTimeoutSec) { $giveUp = 'stalled' }
        if ($canSkip -and $phase -ne 'install') {
            try {
                if ([Console]::KeyAvailable) {
                    $k = [Console]::ReadKey($true)
                    if ($k.KeyChar -eq 's' -or $k.KeyChar -eq 'S') { $giveUp = 'skipped' }
                }
            } catch {}
        }
        if ($giveUp) {
            # an install already under way is never abandoned — walking off mid-install
            # would report "skipped" while Windows keeps installing behind our back
            [System.Threading.Monitor]::Enter($state.SyncRoot)
            try {
                if ($state.Phase -ne 'install') { $state.Abandon = $true; $outcome = $giveUp }
            } finally { [System.Threading.Monitor]::Exit($state.SyncRoot) }
            if ($state.Abandon) { break }
        }

        $elapsed = "{0:mm\:ss}" -f $inPhase
        $spin = $frames[$frameIdx % $frames.Count]
        if ($phase -eq 'install') { $hint = 'installing — not skippable' }
        elseif ($canSkip)         { $hint = 'press S to skip' }
        else                      { $hint = 'running' }
        $line = "      $spin  $Label · $phase  ·  $elapsed  ·  $hint"
        try { [Console]::Write("`r" + $line.PadRight(70)) } catch {}
        $frameIdx++
        Start-Sleep -Milliseconds 250
    }
    try { [Console]::Write("`r" + (' ' * 72) + "`r") } catch {}

    $phaseSec = [int]([DateTime]::UtcNow - $state.PhaseStarted).TotalSeconds
    if ($outcome -eq 'done') {
        try { [void]$ps.EndInvoke($handle) } catch { if (-not $state.Error) { $state.Error = $_.Exception.Message.Split("`n")[0] } }
        try { $ps.Dispose(); $rs.Dispose() } catch {}
    } else {
        # the worker is parked inside a WUA call nothing can cancel from here.
        # ask it to stop and leave it — Dispose would block on that same call.
        try { [void]$ps.BeginStop($null, $null) } catch {}
    }

    [pscustomobject]@{
        Outcome        = $outcome          # done | stalled | skipped
        Phase          = $state.Phase      # where it was when it ended
        PhaseSec       = $phaseSec
        SearchMs       = $state.SearchMs
        Found          = @($state.Found)
        Downloaded     = @($state.Downloaded)
        Failed         = @($state.Failed)  # 'KBnnnn (0xHRESULT)'
        InstallCode    = $state.InstallCode
        RebootRequired = $state.RebootRequired
        Error          = $state.Error
    }
}

# ═══════════════════════════════════════════════════════════════
#  MEND  —  DISM spine, then SFC off the healed store
# ═══════════════════════════════════════════════════════════════
# NOTE: DISM verdict parsing below matches English strings ("No component store
#       corruption detected", "repairable", "completed successfully"). On a
#       localized Windows install these strings differ per language. If Panacea
#       ever needs to run on non-en-US boxes, swap the string matches for
#       parsing "Image Health State:" from %WINDIR%\Logs\DISM\dism.log — that
#       field stays English regardless of OS locale.
Rule 'MEND'
$mendResult = 'none'          # none | repaired | failed
$dismStore  = 'unknown'
$sfcResult  = 'not run'

# --- DISM: CheckHealth (cheap, reads existing flags) -------------
$needScan = $false; $needRestore = $false
Status $G.Work 'dism checkhealth' 'reading component store flags...' $Clr.Cyan
$chk = Invoke-Guarded -File "$env:SystemRoot\System32\dism.exe" -Arguments '/Online /Cleanup-Image /CheckHealth' -TimeoutSec $Panacea.DismCheckTimeoutSec -Label 'dism checkhealth'
if ($chk.Skipped) {
    Status $G.Skip 'dism checkhealth' 'skipped by user — MEND aborted' $Clr.Grey
    $script:Ledger.Warnings.Add('DISM CheckHealth skipped by user')
    $mendResult = 'skipped'
} elseif ($chk.TimedOut) {
    Status $G.Fail 'dism checkhealth' 'timed out' $Clr.Red
    $script:Ledger.Symptoms.Add('DISM CheckHealth timed out')
    $mendResult = 'failed'
} elseif ($chk.StdOut -match 'No component store corruption detected') {
    Status $G.Ok 'dism checkhealth' 'no corruption flagged' $Clr.Green
    $dismStore = 'healthy'
} elseif ($chk.StdOut -match 'repairable') {
    Status $G.Warn 'dism checkhealth' 'repairable corruption flagged' $Clr.Orange
    $needScan = $true
} else {
    # CheckHealth only reads cached flags; escalate to a real scan to be sure
    Status $G.Work 'dism checkhealth' 'inconclusive → escalating to scan' $Clr.Cyan
    $needScan = $true
}

# --- DISM: ScanHealth (slower, actual scan) ----------------------
if ($needScan -and $mendResult -ne 'failed' -and $mendResult -ne 'skipped') {
    Status $G.Work 'dism scanhealth' 'scanning store — DISM output follows' $Clr.Cyan
    Write-Host ''
    $scan = Invoke-Guarded -File "$env:SystemRoot\System32\dism.exe" -Arguments '/Online /Cleanup-Image /ScanHealth' -TimeoutSec $Panacea.DismScanTimeoutSec -Label 'dism scanhealth' -ShowNative
    if ($scan.Skipped) {
        Status $G.Skip 'dism scanhealth' 'skipped by user' $Clr.Grey
        $script:Ledger.Warnings.Add('DISM ScanHealth skipped by user')
        $mendResult = 'skipped'
    } elseif ($scan.TimedOut) {
        Status $G.Fail 'dism scanhealth' 'timed out' $Clr.Red
        $script:Ledger.Symptoms.Add('DISM ScanHealth timed out')
        $mendResult = 'failed'
    } else {
        # verdict via a quick captured CheckHealth (silent, fast)
        $verify = Invoke-Guarded -File "$env:SystemRoot\System32\dism.exe" -Arguments '/Online /Cleanup-Image /CheckHealth' -TimeoutSec 300
        if ($verify.StdOut -match 'No component store corruption detected') {
            Status $G.Ok 'dism scanhealth' 'store clean after scan' $Clr.Green
            $dismStore = 'healthy'
        } else {
            Status $G.Warn 'dism scanhealth' 'corruption confirmed → will restore' $Clr.Orange
            $needRestore = $true
        }
    }
}

# --- DISM: RestoreHealth (the actual cure) -----------------------
if ($needRestore -and $mendResult -ne 'failed' -and $mendResult -ne 'skipped') {
    if ($Panacea.DryRun) {
        Status $G.Skip 'dism restorehealth' 'would repair store from Windows Update (DRY RUN)' $Clr.Grey
        $mendResult = 'would-repair'
        $dismStore = 'flagged (dry run)'
    } else {
    Status $G.Work 'dism restorehealth' 'repairing store from Windows Update — DISM output follows' $Clr.Cyan
    Write-Host ''
    $rest = Invoke-Guarded -File "$env:SystemRoot\System32\dism.exe" -Arguments '/Online /Cleanup-Image /RestoreHealth' -TimeoutSec $Panacea.DismRestoreTimeoutSec -Label 'dism restorehealth' -ShowNative
    if ($rest.Skipped) {
        Status $G.Skip 'dism restorehealth' 'skipped by user — store still corrupt' $Clr.Grey
        $script:Ledger.Warnings.Add('DISM RestoreHealth skipped by user — store left uncured')
        $mendResult = 'skipped'
        $dismStore = 'still corrupt'
    } elseif ($rest.TimedOut) {
        Status $G.Fail 'dism restorehealth' 'timed out (source unreachable?)' $Clr.Red
        $script:Ledger.Symptoms.Add('DISM RestoreHealth timed out — check Windows Update connectivity')
        $mendResult = 'failed'
        $dismStore = 'still corrupt'
    } elseif ($rest.ExitCode -eq 0) {
        # verdict via silent CheckHealth
        $verify = Invoke-Guarded -File "$env:SystemRoot\System32\dism.exe" -Arguments '/Online /Cleanup-Image /CheckHealth' -TimeoutSec 300
        if ($verify.StdOut -match 'No component store corruption detected') {
            Status $G.Ok 'dism restorehealth' 'store repaired' $Clr.Green
            $dismStore = 'repaired'
            $mendResult = 'repaired'
        } else {
            Status $G.Warn 'dism restorehealth' 'ran clean but store still shows corruption' $Clr.Orange
            $script:Ledger.Symptoms.Add('RestoreHealth exit 0 but store still corrupt')
            $mendResult = 'failed'
            $dismStore = 'still corrupt'
        }
    } else {
        Status $G.Fail 'dism restorehealth' "failed (exit $($rest.ExitCode))" $Clr.Red
        $script:Ledger.Symptoms.Add("DISM RestoreHealth failed (exit $($rest.ExitCode))")
        $mendResult = 'failed'
        $dismStore = 'still corrupt'
    }
    } # /DryRun else for RestoreHealth
}

# --- SFC: only meaningful once the store is trustworthy ----------
if ($dismStore -in @('healthy','repaired')) {
    $sfcArgs = if ($Panacea.DryRun) { '/verifyonly' } else { '/scannow' }
    $sfcMsg  = if ($Panacea.DryRun) { 'verifying system files (DRY RUN — no repair) — SFC output follows' } else { 'verifying system files — SFC output follows' }
    Status $G.Work 'sfc scannow' $sfcMsg $Clr.Cyan
    Write-Host ''
    # note CBS.log position so we only read what SFC just appended
    $cbsPath = "$env:SystemRoot\Logs\CBS\CBS.log"
    $cbsBefore = if (Test-Path $cbsPath) { (Get-Item $cbsPath).Length } else { 0 }

    $sfc = Invoke-Guarded -File "$env:SystemRoot\System32\sfc.exe" -Arguments $sfcArgs -TimeoutSec $Panacea.SfcTimeoutSec -Label 'sfc scannow' -ShowNative

    if ($sfc.Skipped) {
        Status $G.Skip 'sfc scannow' 'skipped by user' $Clr.Grey
        $script:Ledger.Warnings.Add('SFC skipped by user')
        $sfcResult = 'skipped'
    } elseif ($sfc.TimedOut) {
        Status $G.Fail 'sfc scannow' 'timed out' $Clr.Red
        $script:Ledger.Symptoms.Add('SFC timed out')
        $sfcResult = 'timed out'
    } else {
        # read only the portion of CBS.log that SFC just appended
        $cbsNew = ''
        try {
            if (Test-Path $cbsPath) {
                $fs = [IO.File]::Open($cbsPath,'Open','Read','ReadWrite')
                [void]$fs.Seek($cbsBefore,'Begin')
                $rdr = New-Object IO.StreamReader($fs)
                $cbsNew = $rdr.ReadToEnd()
                $rdr.Close(); $fs.Close()
            }
        } catch {}

        if ($cbsNew -match 'Cannot repair member file' -or $cbsNew -match '\[SR\].+cannot repair') {
            Status $G.Fail 'sfc scannow' 'found damage it could NOT fix' $Clr.Red
            $script:Ledger.Symptoms.Add('SFC found unfixable corruption')
            $sfcResult = 'unfixable'
            $mendResult = 'failed'
        } elseif ($cbsNew -match '\[SR\] Repairing \d+ components' -and $cbsNew -notmatch 'Repairing 0 components') {
            Status $G.Ok 'sfc scannow' 'violations found and repaired' $Clr.Green
            $sfcResult = 'repaired'
            if ($mendResult -eq 'none') { $mendResult = 'repaired' }
        } elseif ($cbsNew -match '\[SR\] Verify complete' -or $sfc.ExitCode -eq 0) {
            Status $G.Ok 'sfc scannow' 'no integrity violations' $Clr.Green
            $sfcResult = 'clean'
        } else {
            Status $G.Warn 'sfc scannow' "finished (exit $($sfc.ExitCode)) — verdict unclear, see CBS.log" $Clr.Orange
            $sfcResult = "exit $($sfc.ExitCode)"
        }
    }
} else {
    Status $G.Skip 'sfc scannow' 'skipped — store not healthy, would repair from bad source' $Clr.Grey
    $sfcResult = 'skipped (store unhealthy)'
}

# ═══════════════════════════════════════════════════════════════
#  DOSE  —  native updates: Windows Update (COM) + Dell DCU + HP CMSL if present
#           push · stage · SUPPRESS REBOOT · never restart
# ═══════════════════════════════════════════════════════════════

# interactive DOSE gate — offer the tech a chance to skip the whole tier
$doseWanted = $true
$doseInteractive = $false
try { $doseInteractive = -not [Console]::IsInputRedirected } catch { $doseInteractive = $false }
if ($Panacea.PromptDose -and $doseInteractive -and -not $Panacea.DryRun) {
    Write-Host ''
    Write-Host (Paint "   administer updates? [Y/n]  (Windows Update + vendor firmware; suppresses reboot) " -Fg $Clr.Cyan) -NoNewline
    $ans = [Console]::ReadLine()
    if ($ans -match '^\s*[nN]') {
        $doseWanted = $false
        $script:Ledger.Warnings.Add('DOSE tier skipped at operator prompt')
    }
}

Rule 'DOSE'
$wuStaged   = 0;  $wuList = @();  $wuState = 'not run'
$wuFailed   = @(); $wuStuck = $false   # stuck = a download hung or failed; ALKAHEST territory
$dellStaged = 0;  $dellState = 'n/a'
$hpStaged   = 0;  $hpState   = 'n/a'
$doseReboot = $false

if (-not $doseWanted) {
    Status $G.Skip 'entire tier' 'skipped by operator — no updates administered' $Clr.Grey
    $wuState = 'skipped'; $dellState = 'skipped'; $hpState = 'skipped'
}

# --- Windows Update via native WUA COM (no module) ---------------
if ($doseWanted) { try {
    Status $G.Work 'windows update' 'searching (quality + servicing, no drivers/feature)...' $Clr.Cyan

    # sanity check the Windows Update stack BEFORE trusting anything it says
    $wuServiceOK = $false
    try {
        $svc = Get-Service -Name wuauserv -ErrorAction Stop
        $wuServiceOK = ($svc.Status -eq 'Running')
        if (-not $wuServiceOK) {
            # try to start it — some machines disable-by-default
            try { Start-Service wuauserv -ErrorAction Stop; Start-Sleep -Seconds 2; $wuServiceOK = ((Get-Service wuauserv).Status -eq 'Running') } catch {}
        }
    } catch { $wuServiceOK = $false }

    # search → download → install on a worker thread; see WU RUNNER above
    $wuMode = if ($Panacea.DryRun) { 'search' } else { 'install' }
    $wu = Invoke-WuPipeline -Mode $wuMode -DownloadTimeoutSec $Panacea.WuDownloadTimeoutSec -Label 'windows update'
    $wuSearchMs = $wu.SearchMs
    $wuList     = @($wu.Found)
    $wuFailed   = @($wu.Failed)
    $wuMins     = [Math]::Round($wu.PhaseSec / 60)

    if ($wu.Error) {
        Status $G.Fail 'windows update' "WUA error: $($wu.Error)" $Clr.Red
        $script:Ledger.Symptoms.Add('Windows Update via WUA failed — check service health')
        $wuState = 'failed'
    } elseif ($wu.Outcome -ne 'done' -and $wu.Phase -eq 'download') {
        # stuck at "downloading" — the exact wedge Settings shows. install NOT attempted.
        if ($wu.Outcome -eq 'stalled') {
            Status $G.Fail 'windows update' "download stuck — no finish after $wuMins min, nothing installed" $Clr.Red
        } else {
            Status $G.Skip 'windows update' "download skipped by user after $wuMins min — nothing installed" $Clr.Grey
        }
        $script:Ledger.Symptoms.Add("Windows Update download stuck ($($wuList.Count) updates)")
        $wuStuck = $true
        $wuState = 'download stuck'
    } elseif ($wu.Outcome -ne 'done') {
        Status $G.Skip 'windows update' 'search skipped by user' $Clr.Grey
        $script:Ledger.Warnings.Add('Windows Update search skipped by user')
        $wuState = 'skipped'
    } elseif ($wuList.Count -eq 0) {
        # trust check: zero-result + fast + service issues = WUA lied to us
        $wuSuspicious = (-not $wuServiceOK) -or ($wuSearchMs -lt 500)
        if ($wuSuspicious) {
            $why = @()
            if (-not $wuServiceOK) { $why += 'wuauserv not running' }
            if ($wuSearchMs -lt 500) { $why += "search returned in ${wuSearchMs}ms (too fast)" }
            $reason = $why -join '; '
            Status $G.Warn 'windows update' "UNVERIFIED — Windows Update stack looks off: $reason" $Clr.Orange
            $script:Ledger.Symptoms.Add("Windows Update verdict unverified — $reason")
            $wuState = 'unverified'
        } else {
            Status $G.Ok 'windows update' "current — nothing to administer (search ${wuSearchMs}ms)" $Clr.Green
            $wuState = 'current'
        }
    } elseif ($Panacea.DryRun) {
        $kbList = ($wuList | Select-Object -Unique) -join ', '
        Status $G.Skip 'windows update' "would administer $($wuList.Count): $kbList (DRY RUN)" $Clr.Grey
        $wuState = "would install $($wuList.Count)"
    } else {
        # only what actually downloaded got installed; name the rest
        if ($wuFailed.Count -gt 0) {
            Status $G.Warn 'windows update' "$($wuFailed.Count) of $($wuList.Count) did not download: $($wuFailed -join ', ')" $Clr.Orange
            $script:Ledger.Symptoms.Add("Windows Update download failed: $($wuFailed -join ', ')")
            $wuStuck = $true
        }
        if ($wu.Downloaded.Count -eq 0) {
            Status $G.Fail 'windows update' 'nothing downloaded — nothing installed' $Clr.Red
            $wuState = 'download failed'
        } else {
            $wuStaged = $wu.Downloaded.Count
            if ($wu.RebootRequired) { $doseReboot = $true }
            # ResultCode 2 = succeeded, 3 = succeeded w/ errors
            switch ($wu.InstallCode) {
                2 { Status $G.Ok   'windows update' "$wuStaged administered" $Clr.Green; $wuState = "$wuStaged installed" }
                3 { Status $G.Warn 'windows update' "$wuStaged done, some errors" $Clr.Orange; $wuState = "$wuStaged w/ errors" }
                default {
                    Status $G.Warn 'windows update' "finished, result code $($wu.InstallCode)" $Clr.Orange
                    $wuState = "code $($wu.InstallCode)"
                }
            }
        }
    }
} catch {
    Status $G.Fail 'windows update' "WUA error: $($_.Exception.Message.Split("`n")[0])" $Clr.Red
    $script:Ledger.Symptoms.Add('Windows Update via WUA failed — check service health')
    $wuState = 'failed'
} } # /doseWanted gate for Windows Update

# --- Dell Command | Update (dcu-cli) if the box is a Dell w/ DCU -
$dcu = @(
    "${env:ProgramFiles}\Dell\CommandUpdate\dcu-cli.exe",
    "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($doseWanted -and $dcu) {
    Status $G.Work 'dell command' 'scanning for BIOS/firmware/driver updates...' $Clr.Cyan
    $dScan = Invoke-Guarded -File $dcu -Arguments '/scan' -TimeoutSec 600 -Label 'dell scan'
    # dcu-cli /scan returns 0 = updates found, 500 = no updates, 1 = reboot required from prior
    if ($dScan.Skipped) {
        Status $G.Skip 'dell command' 'scan skipped by user' $Clr.Grey
        $dellState = 'skipped'
    } elseif ($dScan.ExitCode -eq 500) {
        Status $G.Ok 'dell command' 'current — nothing to administer' $Clr.Green
        $dellState = 'current'
    } elseif ($dScan.ExitCode -eq 0 -or $dScan.ExitCode -eq 1) {
        if ($Panacea.DryRun) {
            Status $G.Skip 'dell command' 'scan found updates — would apply (DRY RUN)' $Clr.Grey
            $dellState = 'would apply'
        } else {
        Status $G.Work 'dell command' 'applying (reboot suppressed)...' $Clr.Cyan
        $dApply = Invoke-Guarded -File $dcu -Arguments '/applyUpdates -reboot=disable' -TimeoutSec $Panacea.VendorTimeoutSec -Label 'dell apply'
        if ($dApply.Skipped) {
            Status $G.Skip 'dell command' 'apply skipped by user — updates NOT staged' $Clr.Grey
            $script:Ledger.Warnings.Add('Dell DCU apply skipped by user')
            $dellState = 'apply skipped'
        } elseif ($dApply.TimedOut) {
            Status $G.Fail 'dell command' 'apply timed out' $Clr.Red
            $script:Ledger.Symptoms.Add('Dell DCU apply timed out')
            $dellState = 'timed out'
        } else {
            # 0 = success, 1 = success+reboot required, 5 = reboot required
            if ($dApply.ExitCode -in @(1,5)) { $doseReboot = $true }
            $dellStaged = 1
            Status $G.Ok 'dell command' "updates applied (exit $($dApply.ExitCode))" $Clr.Green
            $dellState = "applied (exit $($dApply.ExitCode))"
        }
        } # /DryRun else for DCU apply
    } else {
        Status $G.Warn 'dell command' "scan returned exit $($dScan.ExitCode)" $Clr.Orange
        $dellState = "scan exit $($dScan.ExitCode)"
    }
} else {
    # only report as skipped if it's actually a Dell; otherwise it's just n/a
    $mfg = ''
    try { $mfg = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer } catch {}
    if ($mfg -match 'Dell') {
        Status $G.Warn 'dell command' 'Dell box but DCU not installed — cannot push' $Clr.Orange
        $dellState = 'DCU absent'
    } else {
        Status $G.Skip 'dell command' 'not a Dell — skipped' $Clr.Grey
        $dellState = 'n/a'
    }
}

# --- HP: HPCMSL module OR HPImageAssistant if present ------------
$hpcmsl = Get-Module -ListAvailable -Name HPCMSL -ErrorAction SilentlyContinue
$hpia = @(
    "${env:ProgramFiles}\HP\HPIA\HPImageAssistant.exe",
    "${env:ProgramFiles(x86)}\HP\HPIA\HPImageAssistant.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
$mfgHP = ''
try { $mfgHP = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).Manufacturer } catch {}
if ($doseWanted -and $hpia) {
    $hpAction = if ($Panacea.DryRun) { 'List' } else { 'Install' }
    $hpMsg    = if ($Panacea.DryRun) { 'scanning + listing recommendations (DRY RUN — no install)' } else { 'scanning + applying via HPIA (reboot suppressed)...' }
    Status $G.Work 'hp assistant' $hpMsg $Clr.Cyan
    # /Operation:Analyze then /Action:{Install|List}, silent, no reboot
    $hp = Invoke-Guarded -File $hpia -Arguments "/Operation:Analyze /Action:$hpAction /Selection:All /Silent /noninteractive /BIOSPwdFile:none" -TimeoutSec $Panacea.VendorTimeoutSec -Label 'hp assistant'
    if ($hp.Skipped) {
        Status $G.Skip 'hp assistant' 'skipped by user — updates NOT staged' $Clr.Grey
        $script:Ledger.Warnings.Add('HPIA skipped by user')
        $hpState = 'skipped'
    } elseif ($hp.TimedOut) {
        Status $G.Fail 'hp assistant' 'timed out' $Clr.Red
        $hpState = 'timed out'
    } else {
        # HPIA exit 0 = success, 3010 = reboot required, 256 = no recommendations
        if ($Panacea.DryRun) {
            if ($hp.ExitCode -eq 256) {
                Status $G.Ok 'hp assistant' 'current — no recommendations' $Clr.Green
                $hpState = 'current'
            } else {
                Status $G.Skip 'hp assistant' "recommendations found — would apply (DRY RUN, exit $($hp.ExitCode))" $Clr.Grey
                $hpState = 'would apply'
            }
        } else {
            if ($hp.ExitCode -eq 3010) { $doseReboot = $true; $hpStaged = 1 }
            elseif ($hp.ExitCode -eq 0) { $hpStaged = 1 }
            if ($hp.ExitCode -eq 256) {
                Status $G.Ok 'hp assistant' 'current — no recommendations' $Clr.Green
                $hpState = 'current'
            } else {
                Status $G.Ok 'hp assistant' "applied (exit $($hp.ExitCode))" $Clr.Green
                $hpState = "applied (exit $($hp.ExitCode))"
            }
        }
    }
} elseif ($hpcmsl -and $mfgHP -match 'HP|Hewlett') {
    Status $G.Warn 'hp assistant' 'HPCMSL present but HPIA preferred — skipping auto-push' $Clr.Orange
    $hpState = 'CMSL only'
} else {
    if ($mfgHP -match 'HP|Hewlett') {
        Status $G.Warn 'hp assistant' 'HP box but no HPIA — cannot push' $Clr.Orange
        $hpState = 'HPIA absent'
    } else {
        Status $G.Skip 'hp assistant' 'not an HP — skipped' $Clr.Grey
        $hpState = 'n/a'
    }
}

# ═══════════════════════════════════════════════════════════════
#  PURGE  —  evacuate SYSTEM-generated residue only.
#            user files & recycle bin are SACRED. never touched.
# ═══════════════════════════════════════════════════════════════
Rule 'PURGE'
$reclaimed = 0.0
function Get-DirSizeGB($path) {
    if (-not (Test-Path $path)) { return 0.0 }
    try {
        $items = @(Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue)
        if ($items.Count -eq 0) { return 0.0 }
        $sum = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        if (-not $sum) { return 0.0 }
        return [Math]::Round(($sum/1GB),2)
    } catch { return 0.0 }
}
function Clear-Residue {
    param([string]$Label,[string]$Path,[switch]$ContentsOnly)
    if (-not (Test-Path $Path)) { Status $G.Skip $Label 'not present' $Clr.Grey; return 0.0 }
    $before = Get-DirSizeGB $Path
    if ($Panacea.DryRun) {
        if ($before -gt 0) { Status $G.Skip $Label "would reclaim $before GB (DRY RUN)" $Clr.Grey }
        else               { Status $G.Skip $Label 'already clean (DRY RUN)' $Clr.Grey }
        return 0.0
    }
    try {
        if ($ContentsOnly) {
            Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Remove-Item $Path -Recurse -Force -ErrorAction SilentlyContinue
        }
    } catch {}
    $after = Get-DirSizeGB $Path
    $freed = [Math]::Max(0,[Math]::Round($before - $after,2))
    if ($freed -gt 0) { Status $G.Ok $Label "$freed GB reclaimed" $Clr.Green }
    else              { Status $G.Ok $Label 'already clean' $Clr.Green }
    return $freed
}

# Windows temp — system-generated, safe
$reclaimed += Clear-Residue -Label 'windows temp' -Path "$env:SystemRoot\Temp" -ContentsOnly
# per-machine temp env (usually same as above but belt+suspenders)
if ($env:TEMP -and (Test-Path $env:TEMP) -and ($env:TEMP -notlike "*$env:USERNAME*")) {
    $reclaimed += Clear-Residue -Label 'machine temp' -Path $env:TEMP -ContentsOnly
}
# SoftwareDistribution\Download — safe to flush; Windows Update rebuilds it
try {
    Status $G.Work 'update cache' 'stopping wuauserv to flush download cache...' $Clr.Cyan
    if (-not $Panacea.DryRun) {
        Stop-Service wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service bits -Force -ErrorAction SilentlyContinue
    }
    $reclaimed += Clear-Residue -Label 'update cache' -Path "$env:SystemRoot\SoftwareDistribution\Download" -ContentsOnly
    if (-not $Panacea.DryRun) {
        Start-Service wuauserv -ErrorAction SilentlyContinue
        Start-Service bits -ErrorAction SilentlyContinue
    }
} catch { Status $G.Warn 'update cache' 'could not flush cleanly' $Clr.Orange }
# CBS logs — diagnostic residue, safe to trim (keep the active one)
try {
    $cbsLogs = @(Get-ChildItem "$env:SystemRoot\Logs\CBS" -Filter '*.log' -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -ne 'CBS.log' })
    if ($cbsLogs.Count -gt 0) {
        $cbsGB = [Math]::Round((($cbsLogs | Measure-Object Length -Sum).Sum)/1GB,2)
        if ($Panacea.DryRun) {
            Status $G.Skip 'cbs logs' "would reclaim $cbsGB GB (DRY RUN)" $Clr.Grey
        } else {
            $cbsLogs | Remove-Item -Force -ErrorAction SilentlyContinue
            $reclaimed += $cbsGB
            Status $G.Ok 'cbs logs' "$cbsGB GB reclaimed" $Clr.Green
        }
    } else { Status $G.Ok 'cbs logs' 'already clean' $Clr.Green }
} catch { Status $G.Skip 'cbs logs' 'unreadable' $Clr.Grey }

# WinSxS component cleanup — the biggest reclaim on crusty boxes.
# NEVER pass /resetbase — that makes superseded updates permanently uninstallable.
if ($Panacea.RunWinSxS) {
    if ($Panacea.DryRun) {
        Status $G.Skip 'winsxs cleanup' 'would run DISM StartComponentCleanup (DRY RUN)' $Clr.Grey
    } else {
        Status $G.Work 'winsxs cleanup' 'DISM component cleanup — output follows' $Clr.Cyan
        Write-Host ''
        $wsx = Invoke-Guarded -File "$env:SystemRoot\System32\dism.exe" -Arguments '/Online /Cleanup-Image /StartComponentCleanup' -TimeoutSec $Panacea.WinSxSTimeoutSec -Label 'winsxs cleanup' -ShowNative
        if ($wsx.Skipped) {
            Status $G.Skip 'winsxs cleanup' 'skipped by user' $Clr.Grey
        } elseif ($wsx.TimedOut) {
            Status $G.Warn 'winsxs cleanup' 'timed out — cleanup incomplete' $Clr.Orange
        } elseif ($wsx.ExitCode -eq 0) {
            Status $G.Ok 'winsxs cleanup' 'component store trimmed' $Clr.Green
        } elseif ($wsx.ExitCode -eq 5) {
            # exit 5 = access denied OR no work to do; on a healthy store it's the latter
            Status $G.Ok 'winsxs cleanup' 'already trimmed — nothing to clean' $Clr.Green
        } else {
            Status $G.Warn 'winsxs cleanup' "exit $($wsx.ExitCode)" $Clr.Orange
        }
    }
} else {
    Status $G.Skip 'winsxs cleanup' 'disabled in config' $Clr.Grey
}

# free-space-after for VITALS delta at PROGNOSIS
try {
    $sysDrv = $env:SystemDrive
    $volAfter = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrv'" -ErrorAction Stop
    $script:Ledger.FreeGBAfter = [Math]::Round($volAfter.FreeSpace/1GB,1)
} catch { $script:Ledger.FreeGBAfter = $script:Ledger.FreeGBBefore }

$reclaimed = [Math]::Round($reclaimed,2)
Status $G.Ok 'sacred' 'user files + recycle bin — untouched, always' $Clr.Green

# ═══════════════════════════════════════════════════════════════
#  TONIC  —  opt-in system tweaks. off unless enabled in config.
# ═══════════════════════════════════════════════════════════════
Rule 'TONIC'
$fastBoot = 'not changed'
# Fast Startup = hybrid shutdown. it skips a real kernel restart on "Shut down",
# so uptime lies and pending fixes linger. takes effect on the next shutdown, no reboot needed.
$fbKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
if ($Panacea.DisableFastBoot) {
    try {
        $fbNow = (Get-ItemProperty $fbKey -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
        if ($fbNow -eq 0) {
            Status $G.Ok 'fast boot' 'already disabled' $Clr.Green
            $fastBoot = 'already off'
        } elseif ($Panacea.DryRun) {
            Status $G.Skip 'fast boot' 'would disable Fast Startup (DRY RUN)' $Clr.Grey
            $fastBoot = 'would disable'
        } else {
            if (-not (Test-Path $fbKey)) { New-Item -Path $fbKey -Force | Out-Null }
            Set-ItemProperty -Path $fbKey -Name HiberbootEnabled -Value 0 -Type DWord -ErrorAction Stop
            Status $G.Ok 'fast boot' 'disabled — applies from next shutdown' $Clr.Cyan
            $fastBoot = 'disabled'
        }
    } catch {
        Status $G.Fail 'fast boot' "could not disable: $($_.Exception.Message.Split("`n")[0])" $Clr.Red
        $script:Ledger.Warnings.Add('fast boot disable failed')
        $fastBoot = 'failed'
    }
} else {
    Status $G.Skip 'fast boot' 'disabled in config' $Clr.Grey
}

# ═══════════════════════════════════════════════════════════════
#  PROGNOSIS  —  the label's warning strip. plain roll-up,
#                conditional orange sticker, screaming reboot line.
# ═══════════════════════════════════════════════════════════════

# decide the reboot verdict — DOSE staged anything, or a reboot was already pending
$rebootNeeded = $doseReboot -or ($rbSources.Count -gt 0) -or ($sfcResult -eq 'repaired') -or ($mendResult -eq 'repaired')
$totalStaged  = $wuStaged + $dellStaged + $hpStaged

# overall status tag
if (($script:Ledger.Symptoms.Count -gt 0 -and $mendResult -eq 'failed') -or $wuStuck) {
    $tag = "$($G.Bell) ATTENTION"; $tagColor = $Clr.Orange
} elseif ($mendResult -eq 'repaired' -or $totalStaged -gt 0 -or $reclaimed -gt 0.1) {
    $tag = "$($G.Staff) FIXED"; $tagColor = $Clr.Cyan
} else {
    $tag = "$($G.Ok.Trim('[]')) HEALTHY"; $tagColor = $Clr.Green
    if ($script:VT) { $tag = "$($G.Staff) HEALTHY" }
}

$bar = '═' * 62; $mid = '─' * 62
if (-not $script:VT) { $bar = '=' * 62; $mid = '-' * 62 }
Write-Host ''
Write-Host (Paint "╔$bar╗" -Fg $tagColor)
$title = "  $($G.Rx)  PROGNOSIS"
$pad = 62 - $title.Length - $tag.Length - 2
if ($pad -lt 1) { $pad = 1 }
Write-Host (Paint $title -Fg $tagColor) -NoNewline
Write-Host (Paint ((' ' * $pad) + $tag + '  ') -Fg $tagColor)
Write-Host (Paint "╟$mid╢" -Fg $Clr.Grey)

# --- plain roll-up (flavor in labels, plain nouns in values) -----
function Roll($label,$value) {
    $dots = '.' * [Math]::Max(3, 16 - $label.Length)
    Write-Host (Paint "  $label $dots $value" -Fg $Clr.Grey)
}
switch ($mendResult) {
    'repaired' { Roll 'corruption' 'repaired (DISM/SFC)' }
    'failed'   { Roll 'corruption' 'REPAIR FAILED — see log' }
    'skipped'  { Roll 'corruption' 'repair SKIPPED by user' }
    default    { Roll 'corruption' 'none' }
}
if ($totalStaged -gt 0) {
    $updBits = @()
    if ($wuStaged)   { $updBits += "$wuStaged Windows Update" }
    if ($dellStaged) { $updBits += 'Dell fw' }
    if ($hpStaged)   { $updBits += 'HP fw' }
    Roll 'updates' ("$totalStaged staged (" + ($updBits -join ', ') + ')')
} elseif ($wuStuck) {
    Roll 'updates' 'DOWNLOAD STUCK — nothing installed'
} elseif ($wuState -eq 'unverified') {
    Roll 'updates' 'UNVERIFIED — Windows Update stack looks off'
} elseif ($wuState -eq 'current' -and
          $dellState -in @('current','n/a','DCU absent') -and
          $hpState -in @('current','n/a','HPIA absent','CMSL only')) {
    Roll 'updates' 'current'
} else {
    Roll 'updates' 'see log'
}
Roll 'reclaimed' "$reclaimed GB"
# --- VITALS delta ---
if ($script:Ledger.UptimeText) { Roll 'uptime' $script:Ledger.UptimeText }
$fBefore = [double]$script:Ledger.FreeGBBefore
$fAfter  = [double]$script:Ledger.FreeGBAfter
if ($fBefore -gt 0 -and $fAfter -gt 0) {
    $delta = [Math]::Round($fAfter - $fBefore, 1)
    $sign = if ($delta -gt 0) { '+' } else { '' }
    Roll 'free space' ("{0:F1} → {1:F1} GB ({2}{3:F1})" -f $fBefore, $fAfter, $sign, $delta)
}

# --- auxiliary warning strip — CONDITIONAL. absence = relief. ----
$auxWarnings = @()
if ($rebootNeeded) {
    $why = @()
    if ($totalStaged -gt 0) { $why += "$totalStaged updates" }
    if ($rbSources.Count -gt 0 -and $totalStaged -eq 0) { $why += 'prior pending' }
    if ($mendResult -eq 'repaired') { $why += 'repairs' }
    $auxWarnings += "REBOOT REQUIRED — " + (($why -join ' + ')) + " will not take effect until restart"
}
foreach ($w in $script:Ledger.Warnings) {
    if ($w -notmatch 'reboot pending') { $auxWarnings += $w.ToUpper() }
}
if ($mendResult -eq 'failed') { $auxWarnings += 'CORRUPTION REPAIR FAILED — manual DISM w/ source may be needed' }
if ($sfcResult -eq 'unfixable') { $auxWarnings += 'SFC FOUND UNFIXABLE DAMAGE — investigate before reimage' }
if ($wuState -eq 'unverified') { $auxWarnings += 'WINDOWS UPDATE UNVERIFIED — Windows Update stack may be broken; do not trust "current"' }
if ($wuStuck) { $auxWarnings += 'WINDOWS UPDATE DOWNLOAD STUCK — run ALKAHEST to clear the update cache, then run Panacea again' }

if ($auxWarnings.Count -gt 0) {
    Write-Host (Paint "╟$mid╢" -Fg $Clr.Grey)
    if ($script:VT) {
        Write-Host (Paint ("  {0}{0} AUXILIARY WARNINGS {0}{0}" -f [char]0x2593) -Fg $Clr.Orange)
    } else {
        Write-Host "  ## AUXILIARY WARNINGS ##"
    }
    foreach ($w in $auxWarnings) {
        # orange-background sticker on VT; loud brackets on ASCII
        if ($script:VT) {
            $line = "  $($G.Bell) $w "
            Write-Host (Paint $line -Fg $Clr.Black -Bg $Clr.Orange)
        } else {
            Write-Host "  !! $w !!"
        }
    }
} else {
    Write-Host (Paint "╟$mid╢" -Fg $Clr.Grey)
    Write-Host (Paint "  dispensed by PANACEA · keep out of reach of end users" -Fg $Clr.Grey)
}
Write-Host (Paint "╚$bar╝" -Fg $tagColor)

# --- machine-readable summary for RMM ingest ---------------------
$script:Ledger.Ended = Get-Date
$summary = [ordered]@{
    host          = $script:Ledger.Host
    session       = $script:Ledger.Session
    os            = $script:Ledger.OSBuild
    started       = $script:Ledger.Started.ToString('s')
    ended         = $script:Ledger.Ended.ToString('s')
    dry_run       = [bool]$Panacea.DryRun
    uptime_days   = $script:Ledger.UptimeDays
    uptime_text   = $script:Ledger.UptimeText
    join_type     = $script:Ledger.JoinType
    ad_domain     = $script:Ledger.AdDomain
    aad_tenant    = $script:Ledger.AadTenant
    mdm_enrolled  = [bool]$script:Ledger.MdmEnrolled
    free_gb_before= $script:Ledger.FreeGBBefore
    free_gb_after = $script:Ledger.FreeGBAfter
    mend          = $mendResult
    dism_store    = $dismStore
    sfc           = $sfcResult
    windows_update    = $wuState
    windows_update_kbs= $wuList
    windows_update_failed = @($wuFailed)
    windows_update_stuck  = [bool]$wuStuck
    dell          = $dellState
    hp            = $hpState
    reclaimed_gb  = $reclaimed
    fast_boot     = $fastBoot
    reboot_req    = $rebootNeeded
    symptoms      = @($script:Ledger.Symptoms)
    status        = ($tag -replace '[^A-Za-z]','')
}
try {
    if ($script:LogFile) {
        $jsonPath = [IO.Path]::ChangeExtension($script:LogFile,'json')
        ($summary | ConvertTo-Json -Depth 4) | Out-File -FilePath $jsonPath -Encoding UTF8
    }
} catch {}

# exit code contract: 0 healthy, 1 reboot-needed, 2 needs-attention
# stored in $global:PanaceaExit so RMM/scripting can read it; NO exit call so the remote shell stays alive
try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch {}
if ($mendResult -eq 'failed' -or $sfcResult -eq 'unfixable' -or $wuStuck) { $global:PanaceaExit = 2 }
elseif ($rebootNeeded) { $global:PanaceaExit = 1 }
else { $global:PanaceaExit = 0 }
$exitVal = $global:PanaceaExit
$logPath = $script:LogFile
Write-Host ''
Write-Host (Paint "   dispensary closed  ·  `$PanaceaExit = $exitVal  ·  log: $logPath" -Fg $Clr.Grey)
'@
[ScriptBlock]::Create($panacea).Invoke()