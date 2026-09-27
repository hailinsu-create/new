param(
    [Parameter(Mandatory = $true)] [string]$GodotExe,
    [Parameter(Mandatory = $true)] [string]$TemplateDir,
    [Parameter(Mandatory = $true)] [string]$JavaHome,
    [Parameter(Mandatory = $true)] [string]$AndroidSdk
)

$ErrorActionPreference = 'Stop'
foreach ($path in @($GodotExe, (Join-Path $TemplateDir 'android_debug.apk'),
        (Join-Path $TemplateDir 'android_release.apk'), (Join-Path $TemplateDir 'version.txt'),
        (Join-Path $JavaHome 'bin/java.exe'), (Join-Path $AndroidSdk 'platform-tools/adb.exe'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "M0_MISSING=$path" }
}

$engineVersion = (& $GodotExe --version | Select-Object -First 1).Trim()
$templateVersion = (Get-Content -LiteralPath (Join-Path $TemplateDir 'version.txt') -Raw).Trim()
$javaVersion = ((& (Join-Path $JavaHome 'bin/java.exe') -version 2>&1) | Select-Object -First 1).ToString()
$adbVersion = (& (Join-Path $AndroidSdk 'platform-tools/adb.exe') version | Select-Object -First 1).Trim()
if (-not $engineVersion.StartsWith('4.7.2.stable')) { throw "M0_WRONG_GODOT=$engineVersion" }
if ($templateVersion -ne '4.7.2.stable') { throw "M0_WRONG_TEMPLATES=$templateVersion" }
if ($javaVersion -notmatch 'version "17\.') { throw "M0_WRONG_JAVA=$javaVersion" }

Write-Output "M0_GODOT=$engineVersion"
Write-Output "M0_TEMPLATES=$templateVersion"
Write-Output "M0_JAVA=$javaVersion"
Write-Output "M0_ADB=$adbVersion"
$buildTools = @(Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'build-tools') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
$platforms = @(Get-ChildItem -LiteralPath (Join-Path $AndroidSdk 'platforms') -Directory -ErrorAction SilentlyContinue | ForEach-Object Name)
Write-Output "M0_BUILD_TOOLS=$($buildTools -join ',')"
Write-Output "M0_PLATFORMS=$($platforms -join ',')"
if ('36.0.0' -notin $buildTools -or 'android-36' -notin $platforms) {
    Write-Warning 'Target SDK 36 tools are not fully installed; Godot may export using older build-tools.'
}
& (Join-Path $AndroidSdk 'platform-tools/adb.exe') devices -l
