param(
	[string]$BaseUrl = "http://127.0.0.1:8866",
	[string]$TestRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"
$BaseUrl = $BaseUrl.TrimEnd("/")

function Assert-True([bool]$Condition, [string]$Message) {
	if (-not $Condition) { throw $Message }
}

function Invoke-DoraPost([string]$Path, [hashtable]$Body = @{}) {
	$json = $Body | ConvertTo-Json -Depth 12 -Compress
	return Invoke-RestMethod -Method Post -Uri "$BaseUrl$Path" `
		-ContentType "application/json" -Body $json
}

function New-DoraContent([string]$Path, [string]$Content = "", [bool]$Folder = $false) {
	$result = Invoke-DoraPost "/new" @{path = $Path; content = $Content; folder = $Folder}
	Assert-True $result.success "failed to create Content path ${Path}: $($result.message)"
}

function Stage-TextFile([string]$Root, [string]$Target, [string]$Source) {
	$content = [IO.File]::ReadAllText((Join-Path $TestRoot $Source), [Text.UTF8Encoding]::new($false, $true))
	New-DoraContent "$Root/$Target" $content $false
	$readback = Invoke-DoraPost "/read" @{path = "$Root/$Target"}
	Assert-True $readback.success "Content staging readback failed for ${Target}"
	# Windows PowerShell 5 decodes an application/json response without an
	# explicit charset using the active ANSI codepage. Preserve the strict byte-
	# equivalent comparison for ASCII fixtures; Unicode fixtures are validated
	# by Lua parsing, text rendering, screenshot pixels, and the final status.
	if ($content -notmatch "[^\x00-\x7f]") {
		Assert-True ($readback.content -eq $content) `
			"Content staging round-trip failed for ${Target}"
	}
}

function Upload-BinaryFile([string]$Directory, [string]$Filename, [string]$Source) {
	$sourcePath = Join-Path $TestRoot $Source
	& curl.exe --fail --silent --show-error -X POST `
		-F "file=@${sourcePath};filename=${Filename}" `
		"$BaseUrl/upload?path=$([Uri]::EscapeDataString($Directory))" | Out-Null
	Assert-True ($LASTEXITCODE -eq 0) "failed to upload ${Directory}/${Filename} through Dora Content"
}

function Wait-DoraContent([string]$Path, [string]$Expected, [int]$TimeoutSeconds = 120) {
	$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
	do {
		$result = Invoke-DoraPost "/read" @{path = $Path}
		if ($result.success) {
			Assert-True ($result.content -eq $Expected) `
				"unexpected workflow status at ${Path}: $($result.content)"
			return
		}
		Start-Sleep -Milliseconds 50
	} while ([DateTime]::UtcNow -lt $deadline)
	throw "timed out waiting for workflow status at ${Path}"
}

function ConvertTo-LuaString([string]$Value) {
	return ConvertTo-Json $Value -Compress
}

$status = Invoke-DoraPost "/status"
Assert-True ($status.success -and $status.platform -eq "Windows" -and $status.writablePath) `
	"Windows Dora status is incomplete"

$advancedFiles = @(
	@("host.lua", "Fixtures/MobileAdvancedGraphicsScene/host.lua"),
	@("ShaderMRT/conf.lua", "Fixtures/ShaderMRTScene/conf.lua"),
	@("ShaderMRT/main.lua", "Fixtures/ShaderMRTScene/main.lua"),
	@("ShaderMRT/mrt.frag", "Fixtures/ShaderMRTScene/mrt.frag"),
	@("ShaderGLSL3/main.lua", "Fixtures/ShaderGLSL3Scene/main.lua"),
	@("ShaderInterpolation/main.lua", "Fixtures/ShaderInterpolationScene/main.lua"),
	@("ShaderCustomAttribute/main.lua", "Fixtures/ShaderCustomAttributeScene/main.lua"),
	@("MeshDepth/conf.lua", "Fixtures/MeshDepthScene/conf.lua"),
	@("MeshDepth/main.lua", "Fixtures/MeshDepthScene/main.lua"),
	@("MeshDepth/tint.frag", "Fixtures/MeshDepthScene/tint.frag"),
	@("CanvasReadback/conf.lua", "Fixtures/CanvasReadbackScene/conf.lua"),
	@("CanvasReadback/main.lua", "Fixtures/CanvasReadbackScene/main.lua"),
	@("CompressedImage/main.lua", "Fixtures/CompressedImageScene/main.lua"),
	@("SpriteBatch/main.lua", "Fixtures/SpriteBatchScene/main.lua"),
	@("ParticleSystem/main.lua", "Fixtures/ParticleSystemScene/main.lua"),
	@("TextBatch/conf.lua", "Fixtures/TextBatchScene/conf.lua"),
	@("TextBatch/main.lua", "Fixtures/TextBatchScene/main.lua"),
	@("ImageFont/conf.lua", "Fixtures/ImageFontScene/conf.lua"),
	@("ImageFont/main.lua", "Fixtures/ImageFontScene/main.lua"),
	@("ArrayImageLayer/conf.lua", "Fixtures/ArrayImageLayerScene/conf.lua"),
	@("ArrayImageLayer/main.lua", "Fixtures/ArrayImageLayerScene/main.lua"),
	@("WindowSettings/conf.lua", "Fixtures/WindowSettingsScene/conf.lua"),
	@("WindowSettings/main.lua", "Fixtures/WindowSettingsScene/main.lua")
)
$advancedFolders = @(
	"ShaderMRT", "ShaderGLSL3", "ShaderInterpolation", "ShaderCustomAttribute",
	"MeshDepth", "CanvasReadback", "CompressedImage", "SpriteBatch", "ParticleSystem",
	"TextBatch", "ImageFont", "ArrayImageLayer", "WindowSettings"
)
$advancedExpected = "platform=windows renderer=direct3d shaders=glsl3-interpolation-layout-matrix mrt=2 depth=pass mesh=pass msaa=4 formats=pass compressed=dxt1-layered-capability batch=sprite-array-particle text=retained-imagefont array=maintex-layers window=virtual-queries pixels=pass scenes=13 content=pass"
$advancedRoot = "$($status.writablePath)/.download/love-windows-advanced-graphics"
$advancedStatus = "$advancedRoot/runtime-status.txt"

Invoke-DoraPost "/delete" @{path = $advancedRoot} | Out-Null
try {
	New-DoraContent $advancedRoot "" $true
	foreach ($folder in $advancedFolders) { New-DoraContent "$advancedRoot/$folder" "" $true }
	foreach ($entry in $advancedFiles) { Stage-TextFile $advancedRoot $entry[0] $entry[1] }
	Upload-BinaryFile "$advancedRoot/SpriteBatch" "atlas.png" `
		"Fixtures/SpriteBatchScene/atlas.png"
	Upload-BinaryFile "$advancedRoot/ParticleSystem" "atlas.png" `
		"Fixtures/ParticleSystemScene/atlas.png"
	$rootLua = ConvertTo-LuaString $advancedRoot
	$statusLua = ConvertTo-LuaString $advancedStatus
	$probeStatus = "$advancedRoot/content-probe.txt"
	$probeLua = ConvertTo-LuaString $probeStatus
	$probe = Invoke-DoraPost "/command" @{code = "Content\insertSearchPath 1, ${rootLua}`nassert Content\save ${probeLua}, tostring(Content\exist `"ShaderMRT/main.lua`") .. `"|`" .. Content\getFullPath `"ShaderMRT/main.lua`""; log = $true}
	Assert-True $probe.success "failed to queue Windows Content search-path probe"
	$probeDeadline = [DateTime]::UtcNow.AddSeconds(10)
	do {
		$probeResult = Invoke-DoraPost "/read" @{path = $probeStatus}
		if ($probeResult.success) { break }
		Start-Sleep -Milliseconds 50
	} while ([DateTime]::UtcNow -lt $probeDeadline)
	Assert-True ($probeResult.success -and $probeResult.content.StartsWith("true|")) `
		"Windows Content search-path probe failed: $($probeResult.content)"
	$command = Invoke-DoraPost "/command" @{code = "package.loaded.host = nil`nwindowsAdvancedWorkflow = require `"host`"`nwindowsAdvancedWorkflow.run ${statusLua}"; log = $true}
	Assert-True $command.success "failed to queue Windows advanced graphics workflow"
	Wait-DoraContent $advancedStatus $advancedExpected 180
	Write-Output "LOVE_WINDOWS_DIRECT3D_ADVANCED_GRAPHICS_PASS scenes=13 pixels=pass content=pass"
} finally {
	$rootLua = ConvertTo-LuaString $advancedRoot
	Invoke-DoraPost "/command" @{code = "windowsAdvancedWorkflow = nil`nContent\removeSearchPath ${rootLua}"; log = $false} | Out-Null
	Invoke-DoraPost "/delete" @{path = $advancedRoot} | Out-Null
}

$non2DRoot = "$($status.writablePath)/.download/love-windows-shader-non2d"
$non2DStatus = "$non2DRoot/runtime-status.txt"
$non2DExpected = "single=array+cube+volume arrays=array+cube+volume dynamic-index=pass type-guard=pass pixels=pass"
Invoke-DoraPost "/delete" @{path = $non2DRoot} | Out-Null
try {
	New-DoraContent $non2DRoot "" $true
	Stage-TextFile $non2DRoot "host.lua" `
		"Fixtures/ShaderNon2DTextureScene/host.lua"
	Stage-TextFile $non2DRoot "main.lua" `
		"Fixtures/ShaderNon2DTextureScene/main.lua"
	$rootLua = ConvertTo-LuaString $non2DRoot
	$statusLua = ConvertTo-LuaString $non2DStatus
	$command = Invoke-DoraPost "/command" @{code = "Content\insertSearchPath 1, ${rootLua}`npackage.loaded.host = nil`nwindowsNon2DWorkflow = require `"host`"`nwindowsNon2DWorkflow.run ${statusLua}"; log = $true}
	Assert-True $command.success "failed to queue Windows non-2D Shader workflow"
	Wait-DoraContent $non2DStatus $non2DExpected 120
	Write-Output "LOVE_WINDOWS_DIRECT3D_NON2D_SAMPLER_PASS $non2DExpected"
} finally {
	$rootLua = ConvertTo-LuaString $non2DRoot
	Invoke-DoraPost "/command" @{code = "windowsNon2DWorkflow = nil`nContent\removeSearchPath ${rootLua}"; log = $false} | Out-Null
	Invoke-DoraPost "/delete" @{path = $non2DRoot} | Out-Null
}

$physicsRoot = "$($status.writablePath)/.download/love-windows-physics"
$physicsStatus = "$physicsRoot/runtime-status.txt"
$physicsExpected = "platform=windows physics=playrho callbacks=pass joints=11 ccd=pass pixels=pass content=pass"
$physicsFiles = @(
	@("host.lua", "Fixtures/MobilePhysicsScene/host.lua"),
	@("conf.lua", "Fixtures/MobilePhysicsScene/conf.lua"),
	@("main.lua", "Fixtures/PhysicsScene/main.lua"),
	@("boot.lua", "Fixtures/PhysicsScene/boot.lua")
)
Invoke-DoraPost "/delete" @{path = $physicsRoot} | Out-Null
try {
	New-DoraContent $physicsRoot "" $true
	foreach ($entry in $physicsFiles) { Stage-TextFile $physicsRoot $entry[0] $entry[1] }
	$rootLua = ConvertTo-LuaString $physicsRoot
	$statusLua = ConvertTo-LuaString $physicsStatus
	$command = Invoke-DoraPost "/command" @{code = "Content\insertSearchPath 1, ${rootLua}`npackage.loaded.host = nil`nwindowsPhysicsWorkflow = require `"host`"`nwindowsPhysicsWorkflow.run ${statusLua}"; log = $true}
	Assert-True $command.success "failed to queue Windows full Physics workflow"
	Wait-DoraContent $physicsStatus $physicsExpected 180
	Write-Output "LOVE_WINDOWS_DIRECT3D_PHYSICS_PASS backend=PlayRho callbacks=pass joints=11 ccd=pass pixels=pass content=pass"
} finally {
	$rootLua = ConvertTo-LuaString $physicsRoot
	Invoke-DoraPost "/command" @{code = "windowsPhysicsWorkflow = nil`nContent\removeSearchPath ${rootLua}"; log = $false} | Out-Null
	Invoke-DoraPost "/delete" @{path = $physicsRoot} | Out-Null
}

$multiRoot = "$($status.writablePath)/.download/love-windows-multi-runtime"
$multiStatus = "$multiRoot/runtime-status.txt"
$multiExpected = "platform=windows graphics=pass pixels=pass audio=soloud systemmix=unsupported system=pass multi=2 input=injected stats=pass content=pass"
$multiFiles = @(
	@("conf.lua", "Fixtures/MobileRuntimeScene/conf.lua"),
	@("common.lua", "Fixtures/MobileRuntimeScene/common.lua"),
	@("first.lua", "Fixtures/MobileRuntimeScene/first.lua"),
	@("second.lua", "Fixtures/MobileRuntimeScene/second.lua"),
	@("host.lua", "Fixtures/MobileRuntimeScene/host.lua")
)
Invoke-DoraPost "/delete" @{path = $multiRoot} | Out-Null
try {
	New-DoraContent $multiRoot "" $true
	foreach ($entry in $multiFiles) { Stage-TextFile $multiRoot $entry[0] $entry[1] }
	$rootLua = ConvertTo-LuaString $multiRoot
	$statusLua = ConvertTo-LuaString $multiStatus
	$command = Invoke-DoraPost "/command" @{code = "Content\insertSearchPath 1, ${rootLua}`npackage.loaded.host = nil`nwindowsMultiRuntimeWorkflow = require `"host`"`nwindowsMultiRuntimeWorkflow.run ${statusLua}"; log = $true}
	Assert-True $command.success "failed to queue Windows multi-runtime workflow"
	Wait-DoraContent $multiStatus $multiExpected 120
	Write-Output "LOVE_WINDOWS_MULTI_RUNTIME_PASS instances=2 graphics=pass pixels=pass audio=SoLoud-lifecycle input=injected stats=pass content=pass"
} finally {
	$rootLua = ConvertTo-LuaString $multiRoot
	Invoke-DoraPost "/command" @{code = "windowsMultiRuntimeWorkflow = nil`nContent\removeSearchPath ${rootLua}"; log = $false} | Out-Null
	Invoke-DoraPost "/delete" @{path = $multiRoot} | Out-Null
}

$systemRoot = "$($status.writablePath)/.download/love-windows-system"
$systemStatus = "$systemRoot/runtime-status.txt"
$systemExpected = "platform=windows system=pass clipboard=roundtrip power=pass url-policy=pass"
$systemFiles = @(
	@("host.lua", "Fixtures/SystemScene/host.lua"),
	@("main.lua", "Fixtures/SystemScene/main.lua"),
	@("boot.lua", "Fixtures/SystemScene/boot.lua")
)
Invoke-DoraPost "/delete" @{path = $systemRoot} | Out-Null
try {
	New-DoraContent $systemRoot "" $true
	foreach ($entry in $systemFiles) { Stage-TextFile $systemRoot $entry[0] $entry[1] }
	$rootLua = ConvertTo-LuaString $systemRoot
	$statusLua = ConvertTo-LuaString $systemStatus
	$command = Invoke-DoraPost "/command" @{code = "Content\insertSearchPath 1, ${rootLua}`npackage.loaded.host = nil`nwindowsSystemWorkflow = require `"host`"`nwindowsSystemWorkflow.run ${statusLua}"; log = $true}
	Assert-True $command.success "failed to queue Windows system workflow"
	Wait-DoraContent $systemStatus $systemExpected 60
	Write-Output "LOVE_WINDOWS_SYSTEM_PASS clipboard=roundtrip power=pass url-policy=pass"
} finally {
	$rootLua = ConvertTo-LuaString $systemRoot
	Invoke-DoraPost "/command" @{code = "windowsSystemWorkflow = nil`nContent\removeSearchPath ${rootLua}"; log = $false} | Out-Null
	Invoke-DoraPost "/delete" @{path = $systemRoot} | Out-Null
}
