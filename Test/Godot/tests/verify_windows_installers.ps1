param([Parameter(Mandatory=$true)][string]$Packages, [Parameter(Mandatory=$true)][string]$Version, [string]$EngineRoot=$env:DORA_ENGINE_ROOT)
$ErrorActionPreference='Stop'
$Packages=[IO.Path]::GetFullPath($Packages)
$root=Join-Path $env:LOCALAPPDATA 'Programs\Dora SSR'
if (Test-Path -LiteralPath $root) { throw "Installer acceptance requires a clean test account: $root already exists" }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$installed=$null
$failure=$null
function Install([string]$file,[string]$label) {
    $args=@('/i',('"'+$file+'"'),'/qn','/norestart','/L*v',('"'+(Join-Path $Packages ($label+'.log'))+'"'))
    $p=Start-Process "$env:SystemRoot\System32\msiexec.exe" -ArgumentList $args -Wait -PassThru
    if ($p.ExitCode -notin @(0,3010)) { throw "MSI $label failed: $($p.ExitCode)" }
    $script:installed=$file
}
try {
    foreach ($backend in @('d3d12','wgl')) {
        $suffix=if($backend -eq 'wgl'){'-opengl'}else{''}
        $stem="dora-ssr-$Version-windows-x64$suffix"
        foreach ($extension in @('zip','msi')) {
            if (-not (Test-Path (Join-Path $Packages ($stem+'.'+$extension)))) { throw "Missing $stem.$extension" }
        }
        Install (Join-Path $Packages ($stem+'.msi')) "install-$backend"
        $distribution=Get-Content -Raw (Join-Path $root 'DoraDistribution.json') | ConvertFrom-Json
        if ($distribution.backend -ne $backend -or $distribution.architecture -ne 'x64') { throw 'Installed backend/architecture mismatch' }
        if ((Get-Content -Raw (Join-Path $root 'DoraInstallation.json') | ConvertFrom-Json).format -ne 'msi') { throw 'MSI installation marker missing' }
        $archive=[IO.Compression.ZipFile]::OpenRead((Join-Path $Packages ($stem+'.zip')))
        try {
            if ($archive.GetEntry('DoraInstallation.json')) { throw 'MSI marker leaked into portable ZIP' }
            foreach ($entry in $archive.Entries) {
                if ($entry.FullName.EndsWith('/')) { continue }
                $file=Join-Path $root $entry.FullName
                if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "MSI missing ZIP payload: $($entry.FullName)" }
                $stream=$entry.Open();$sha=[Security.Cryptography.SHA256]::Create()
                try {$expected=[BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','')} finally {$stream.Dispose();$sha.Dispose()}
                if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $expected) { throw "MSI/ZIP content mismatch: $($entry.FullName)" }
            }
        } finally {$archive.Dispose()}
        $data=Join-Path $env:APPDATA 'IppClub\DoraSSR\DoraReleaseAcceptance-user-data.txt'
        New-Item -ItemType Directory -Force (Split-Path $data) | Out-Null
        Set-Content -LiteralPath $data -Value 'preserve user data'
    }
    # A same-version switch back exercises the actual SelfUpdater installer
    # helper (without launching graphics), rather than only msiexec directly.
    $default=Join-Path $Packages "dora-ssr-$Version-windows-x64.msi"
    if ($EngineRoot) {
        $global:LASTEXITCODE=73 # A successful helper must overwrite stale caller status.
        & (Join-Path $EngineRoot 'Assets/Script/Tools/SelfUpdater/InstallWindows.ps1') -Installer $default -InstallRoot $root -NoLaunch -LogPath (Join-Path $Packages 'switch-back.log')
        if ($LASTEXITCODE -ne 0) { throw 'SelfUpdater MSI helper failed' }
        $installed=$default
        $global:LASTEXITCODE=$null # Also cover a clean caller with no prior native command.
        & (Join-Path $EngineRoot 'Assets/Script/Tools/SelfUpdater/InstallWindows.ps1') -Installer $default -InstallRoot $root -NoLaunch -LogPath (Join-Path $Packages 'repair.log')
        if ($LASTEXITCODE -ne 0) { throw 'Same-backend MSI repair failed' }
    } else { Install $default 'switch-back' }
    if ((Get-Content -Raw (Join-Path $root 'DoraDistribution.json')|ConvertFrom-Json).backend -ne 'd3d12') { throw 'Switch-back failed' }
    Write-Output 'PASS: ZIP/MSI payload equality, MSI detection, same-version D3D12/OpenGL switches and repeated repair'
} catch {
    $failure=$_
    throw
} finally {
    try {
        if ($installed) {
            # A helper may fail after a successful backend replacement. Resolve the
            # currently registered product rather than uninstalling a stale package.
            $service=New-Object -ComObject WindowsInstaller.Installer
            foreach ($package in Get-ChildItem -LiteralPath $Packages -Filter '*.msi') {
                $database=$service.OpenDatabase($package.FullName,0)
                $view=$database.OpenView("SELECT Value FROM Property WHERE Property='ProductCode'")
                $view.Execute();$record=$view.Fetch();$code=$record.StringData(1);$view.Close()
                if ($service.ProductState($code) -eq 5) {$installed=$package.FullName;break}
            }
            $p=Start-Process "$env:SystemRoot\System32\msiexec.exe" -ArgumentList @('/x',('"'+$installed+'"'),'/qn','/norestart','/L*v',('"'+(Join-Path $Packages 'uninstall.log')+'"')) -PassThru -Wait
            if ($p.ExitCode -notin @(0,3010)) { throw "MSI uninstall failed: $($p.ExitCode)" }
            if (Test-Path (Join-Path $root 'Dora.exe')) { throw 'Uninstall left the executable behind' }
            if (-not (Test-Path $data)) { throw 'User data was removed by uninstall' }
            Remove-Item -LiteralPath $data
        }
    } catch {
        if ($failure) { Write-Warning "Installer cleanup also failed: $_" } else { throw }
    }
}
