param(
    [switch]$WarningsAsErrors
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$errors = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-ValidationError([string]$message) {
    $errors.Add($message)
}

function Add-ValidationWarning([string]$message) {
    $warnings.Add($message)
}

function Get-RelativePath([string]$path) {
    return $path.Substring($projectRoot.Length + 1).Replace("\", "/")
}

function Get-ProjectFiles([string[]]$extensions) {
    Get-ChildItem -Path $projectRoot -Recurse -File |
        Where-Object {
            $extensions -contains $_.Extension.ToLowerInvariant() -and
            $_.FullName -notmatch "\\addons\\" -and
            $_.FullName -notmatch "\\.godot\\"
        }
}

$textFiles = Get-ProjectFiles @(".gd", ".tscn", ".tres", ".md", ".godot")
$characterScenesRoot = Join-Path $projectRoot "scenes\characters"
$characterScenes = @()
if (Test-Path -LiteralPath $characterScenesRoot) {
    $characterScenes = Get-ChildItem -Path $characterScenesRoot -Recurse -Filter "*.tscn" -File
}

foreach ($scene in $characterScenes) {
    $content = Get-Content -LiteralPath $scene.FullName -Raw
    $relative = Get-RelativePath $scene.FullName
    if ($content -match '\[sub_resource type="SpriteFrames"') {
        Add-ValidationError "$relative embeds SpriteFrames. Move animation frames to res://resources/characters/."
    }
    if ($content -match 'sprite_frames = SubResource') {
        Add-ValidationError "$relative uses sprite_frames = SubResource(...). Use an external SpriteFrames resource."
    }
    if ($content -match 'sprite_frames = ExtResource' -and $content -notmatch 'res://resources/characters/') {
        Add-ValidationWarning "$relative uses external SpriteFrames, but no resources/characters path was found in the scene."
    }
}

$stalePatterns = @(
    'res://scenes/characters/(Saorise|MaleVillager|FemaleVillager|ElderVillager|Dulluhan|Vincent|Banshee|banshee_projectile)\.tscn',
    'res://resources/dialogue/(villager_|dulluhan_story_profile|vincent_story_profile|banshee_village_)',
    'res://scripts/global/BansheeVillageFlowController\.gd',
    'res://scripts/global/VincentHouseInteriorController\.gd',
    'res://scripts/global/banshee_village/'
)

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relative = Get-RelativePath $file.FullName
    foreach ($pattern in $stalePatterns) {
        if ($content -match $pattern) {
            Add-ValidationError "$relative contains stale path pattern: $pattern"
        }
    }
}

$dialogueRoot = Join-Path $projectRoot "resources\dialogue"
if (Test-Path -LiteralPath $dialogueRoot) {
    $topLevelDialogue = Get-ChildItem -LiteralPath $dialogueRoot -File -Filter "*.tres"
    foreach ($file in $topLevelDialogue) {
        Add-ValidationError "$(Get-RelativePath $file.FullName) is directly under resources/dialogue. Move it under npcs/ or levels/."
    }
}

$globalRoot = Join-Path $projectRoot "scripts\global"
if (Test-Path -LiteralPath $globalRoot) {
    $globalFiles = Get-ChildItem -Path $globalRoot -Recurse -File -Filter "*.gd"
    foreach ($file in $globalFiles) {
        $relative = Get-RelativePath $file.FullName
        if ($relative -match 'scripts/global/banshee_village' -or $file.Name -eq "BansheeVillageFlowController.gd" -or $file.Name -eq "VincentHouseInteriorController.gd") {
            Add-ValidationError "$relative is level-specific but lives under scripts/global."
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($warning in $warnings) {
        Write-Host "  - $warning" -ForegroundColor Yellow
    }
}

if ($errors.Count -gt 0 -or ($WarningsAsErrors -and $warnings.Count -gt 0)) {
    Write-Host "Project structure validation failed." -ForegroundColor Red
    foreach ($validationError in $errors) {
        Write-Host "  - $validationError" -ForegroundColor Red
    }
    if ($WarningsAsErrors -and $warnings.Count -gt 0) {
        foreach ($warning in $warnings) {
            Write-Host "  - Warning treated as error: $warning" -ForegroundColor Red
        }
    }
    exit 1
}

Write-Host "Project structure validation passed." -ForegroundColor Green
exit 0
