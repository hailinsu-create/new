param(
    [Parameter(Mandatory = $true)]
    [string]$GodotExe
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixtureId = [guid]::NewGuid().ToString('N')
$fixtureDir = Join-Path $projectRoot "build/ambush_test_runs/sentinel_$fixtureId"
$fakeAppData = Join-Path $fixtureDir 'player_appdata'
$fakeSaveDir = Join-Path $fakeAppData 'Godot/app_userdata/Ambush Loop'
New-Item -ItemType Directory -Path $fakeSaveDir -Force | Out-Null
$save = Join-Path $fakeSaveDir 'ambush_loop.cfg'
$settings = Join-Path $fakeSaveDir 'ambush_loop_settings.cfg'
[IO.File]::WriteAllBytes($save, [Text.Encoding]::UTF8.GetBytes("fake player progress $fixtureId"))
[IO.File]::WriteAllBytes($settings, [Text.Encoding]::UTF8.GetBytes("fake player settings $fixtureId"))
$beforeSave = (Get-FileHash -LiteralPath $save -Algorithm SHA256).Hash
$beforeSettings = (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash
$launcher = Join-Path $PSScriptRoot 'run_isolated_test.ps1'
$pwsh = (Get-Command pwsh).Source
$previousAppData = $env:APPDATA
$previousProbeMode = $env:AMBUSH_PROBE_MODE

function Assert-SentinelUnchanged {
    if ((Get-FileHash -LiteralPath $save -Algorithm SHA256).Hash -ne $beforeSave -or
        (Get-FileHash -LiteralPath $settings -Algorithm SHA256).Hash -ne $beforeSettings) {
        throw 'Simulated player save or settings changed.'
    }
}

function Start-Probe([string]$mode) {
    $env:AMBUSH_PROBE_MODE = $mode
    $stdout = Join-Path $fixtureDir "$mode.stdout.log"
    $stderr = Join-Path $fixtureDir "$mode.stderr.log"
    return Start-Process -FilePath $pwsh -ArgumentList @(
        '-NoProfile', '-File', ('"' + $launcher + '"'),
        '-GodotExe', ('"' + [IO.Path]::GetFullPath($GodotExe) + '"'),
        '-Entry', 'storage_probe.gd'
    ) -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdout -RedirectStandardError $stderr
}

try {
    $env:APPDATA = $fakeAppData
    foreach ($mode in @('normal', 'assertion_failure')) {
        $proc = Start-Probe $mode
        $proc.WaitForExit()
        $proc.Refresh()
        $expected = if ($mode -eq 'normal') { 0 } else { 42 }
        if ($proc.ExitCode -ne $expected) {
            throw "$mode exited $($proc.ExitCode), expected $expected. See $fixtureDir"
        }
        Assert-SentinelUnchanged
        Write-Output "SENTINEL_OK_$mode exit=$($proc.ExitCode)"
    }

    $runParent = Join-Path $projectRoot 'build/ambush_test_runs'
    $existingRuns = @(Get-ChildItem -LiteralPath $runParent -Directory | ForEach-Object Name)
    $proc = Start-Probe 'forced_termination'
    $child = $null
    $probeLog = $null
    for ($i = 0; $i -lt 150; $i++) {
        $matches = @(Get-CimInstance Win32_Process | Where-Object {
            $_.Name -eq 'Godot_v4.7.2-stable_win64.exe' -and
            $_.CommandLine -like '*storage_probe.gd*'
        })
        if ($matches.Count -eq 1) {
            $child = $matches[0]
            $newRun = Get-ChildItem -LiteralPath $runParent -Directory | Where-Object {
                $_.Name -match '^[0-9a-f]{32}$' -and $_.Name -notin $existingRuns
            } | Select-Object -First 1
            if ($newRun) {
                $candidate = Join-Path $newRun.FullName 'run.log'
                if ((Test-Path -LiteralPath $candidate) -and
                    (Select-String -LiteralPath $candidate -SimpleMatch 'PROBE_WROTE_ISOLATED' -Quiet)) {
                    $probeLog = $candidate
                    break
                }
            }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($null -eq $child -or $null -eq $probeLog) {
        throw 'Forced-termination probe did not reach the isolated write.'
    }
    Stop-Process -Id $child.ProcessId -Force
    if (-not $proc.WaitForExit(20000)) {
        throw 'Launcher did not finish after its test child was terminated.'
    }
    Assert-SentinelUnchanged
    Write-Output "SENTINEL_OK_forced_termination child_pid=$($child.ProcessId)"
    Write-Output "SENTINEL_FIXTURE=$fixtureDir"
}
finally {
    $env:APPDATA = $previousAppData
    $env:AMBUSH_PROBE_MODE = $previousProbeMode
}
