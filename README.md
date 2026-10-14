# ℞ Panacea

**A single-paste Windows tune-up for MSP techs.** Paste it into an elevated PowerShell prompt, and it checks the machine, repairs the component store, installs updates, clears system junk, and hands you a report you can read in five seconds.

Native Windows tools only. No modules to install, nothing to download, no compiled code. It never reboots the machine and never touches user files.

```
   ██████╗  █████╗ ███╗   ██╗ █████╗  ██████╗███████╗ █████╗
   ██╔══██╗██╔══██╗████╗  ██║██╔══██╗██╔════╝██╔════╝██╔══██╗
   ██████╔╝███████║██╔██╗ ██║███████║██║     █████╗  ███████║
   ██╔═══╝ ██╔══██║██║╚██╗██║██╔══██║██║     ██╔══╝  ██╔══██║
   ██║     ██║  ██║██║ ╚████║██║  ██║╚██████╗███████╗██║  ██║
   ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚═╝  ╚═╝
   ℞  THE UNIVERSAL REMEDY  ·  apothecary systems
```

## What it does

Panacea runs in six stages, each named like a step on a prescription label.

| Stage | What happens |
|---|---|
| **DIAGNOSE** | Preflight checks: elevation, free disk space, pending reboots, CPU/RAM load, battery vs AC, uptime, and how the machine is joined (AD, Entra ID, hybrid, Intune-enrolled). Stops here if it isn't running as admin or SYSTEM. |
| **MEND** | Escalates DISM in order (CheckHealth, then ScanHealth, then RestoreHealth) only as far as the machine needs. Runs SFC only once the component store is confirmed healthy, so it never repairs from a corrupt source. |
| **DOSE** | Installs Windows quality and servicing updates through the native Windows Update API. Runs Dell Command Update or HP Image Assistant when present. Feature upgrades and drivers are excluded, and reboots are always suppressed. |
| **PURGE** | Clears system-generated junk only: Windows temp, the update download cache, old CBS logs, and a WinSxS component cleanup. User files and the Recycle Bin are never touched. |
| **TONIC** | Optional tweaks, off by default. Currently: disable Fast Startup, so "Shut down" actually restarts the kernel. |
| **PROGNOSIS** | A one-glance summary marked **HEALTHY**, **FIXED** or **ATTENTION**, with a reboot warning and anything else you need to act on. |

## Built for the real world

- **Won't hang your session.** Every long operation can be skipped with **S**. A Windows Update download that hasn't finished after two hours is treated as stuck: Panacea stops waiting, installs nothing, and tells you so.

- **Doesn't trust a too-good answer.** If Windows Update reports "nothing to install" but the service is down or the search came back suspiciously fast, the result is marked **UNVERIFIED** instead of current.

- **Checks each update's own result.** Windows Update can report a batch as successful when half the downloads are missing. Panacea installs only what actually downloaded and lists the rest by KB number.

- **Dry run mode.** Reports what it *would* do without changing anything.

- **Degrades cleanly.** Full color with Unicode glyphs where the console supports it, plain ASCII where it doesn't (older consoles, RMM output windows).

## Usage

1. Open PowerShell as Administrator, or a ScreenConnect backstage session (runs as SYSTEM).
2. Paste the entire contents of `panacea_paste.ps1` and press Enter.

In an interactive session, a setup panel appears first:

```
── DISPENSARY SETUP
   [1] DryRun ............ OFF   will make real changes when run
   [2] Prompt DOSE ....... ON    will ask before installing updates
   [3] WinSxS cleanup .... ON    will trim Windows component store
   [4] Timeouts .......... ∞     no time limit — best for slow PCs
   [5] Reboot policy ..... warn  runs even if reboot is already pending
   [6] Disable fast boot . OFF   will leave Fast Startup as it is

   [Enter] proceed  ·  [Q] quit
```

Type a number to toggle that option, press Enter to run, or Q to quit without changing anything. In non-interactive contexts (SYSTEM, RMM) the panel is skipped and the defaults from the config block are used.

## Configuration

All settings live in the `CONFIG BLOCK` at the top of the script.

| Setting | Default | Meaning |
|---|---|---|
| `DryRun` | `$false` | Report only, change nothing |
| `PromptDose` | `$true` | Ask before installing updates (interactive only) |
| `RunWinSxS` | `$true` | Run DISM component cleanup during PURGE |
| `DisableFastBoot` | `$false` | Turn off Fast Startup during TONIC |
| `RebootPolicy` | `'warn'` | `'warn'` flags a pending reboot and continues; `'stop'` halts |
| `MinFreeGB` | `15` | Free space below this is flagged as a symptom |
| `MaxCpuPct` / `MaxRamPct` | `70` / `90` | Load above this is flagged as a busy machine |
| `WuDownloadTimeoutSec` | `7200` | When a Windows Update download counts as stuck |
| `*TimeoutSec` (DISM, SFC, vendor) | `0` | `0` means no limit; slow machines are normal |
| `NoColor` | `$false` | Force the plain ASCII display |

## Output for RMM

Each run writes two files to `%ProgramData%\Panacea\TuneUp\`:

- `panacea_<HOST>_<timestamp>.log`, the full transcript
- `panacea_<HOST>_<timestamp>.json`, a machine-readable summary (join type, repair results, updates installed or failed, space reclaimed, reboot needed, overall status)

The result is also left in `$PanaceaExit` instead of being passed to `exit`, so a backstage session stays open afterwards:

| `$PanaceaExit` | Meaning |
|---|---|
| `0` | Healthy |
| `1` | Reboot needed |
| `2` | Needs attention (repair failed, unfixable SFC damage, stuck update download, or a halted preflight) |

## Requirements

- Windows 10 or 11
- PowerShell 5.1 or later
- Administrator or SYSTEM
- **English (en-US) Windows.** DISM results are read from its English output text. Other languages will run, but repair verdicts may come back as inconclusive.

## Safety

- Never reboots. Every update path suppresses restarts; PROGNOSIS tells you when one is needed.
- Never touches user profiles, user temp folders or the Recycle Bin.
- Never runs DISM `/ResetBase`, so installed updates stay uninstallable.
- Never installs feature upgrades or drivers through Windows Update.

## Credits

Designed, directed and field-tested by Kaylee. Code written with AI assistance.

## License

[MIT](LICENSE)

*Dispensed by PANACEA · keep out of reach of end users.*
