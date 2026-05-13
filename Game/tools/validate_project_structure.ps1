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

function Convert-ResPathToFullPath([string]$resPath) {
    if (-not $resPath.StartsWith("res://")) {
        return ""
    }

    $relativePath = $resPath.Substring(6).Replace("/", "\")
    return Join-Path $projectRoot $relativePath
}

$textFiles = Get-ProjectFiles @(".gd", ".tscn", ".tres", ".md", ".godot")
$sceneFiles = Get-ProjectFiles @(".tscn")
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
    'res://scripts/global/BansheeRouteEncounterController\.gd',
    'res://scripts/levels/shared/BansheeRouteEncounterController\.gd',
    'BansheeRouteEncounterController',
    'res://scripts/global/banshee_village/',
    'res://scenes/levels/InitialSpawn\.tscn',
    'Level-InitialSpawn',
    'InitialSpawnOption',
    'res://templates/route_level/',
    'Route Level Template',
    'Route\s+[0-9]+'
)

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $relative = Get-RelativePath $file.FullName
    if ($relative -eq "tools/validate_project_structure.ps1") {
        continue
    }
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

$saveManagerPath = Join-Path $projectRoot "scripts\global\SaveManager.gd"
if (Test-Path -LiteralPath $saveManagerPath) {
    $saveManagerContent = Get-Content -LiteralPath $saveManagerPath -Raw
    $categoryValues = @{}
    $categoryMatches = [regex]::Matches($saveManagerContent, 'const (LEVEL_CATEGORY_[A-Z0-9_]+) := "([^"]+)"')
    foreach ($match in $categoryMatches) {
        $categoryValues[$match.Groups[1].Value] = $match.Groups[2].Value
    }

    $allowedCategories = New-Object System.Collections.Generic.HashSet[string]
    foreach ($value in $categoryValues.Values) {
        [void]$allowedCategories.Add($value)
    }

    $sceneConstantToPath = @{}
    $sceneConstantMatches = [regex]::Matches($saveManagerContent, 'const ([A-Z0-9_]+_SCENE) := "(res://scenes/levels/[^"]+\.tscn)"')
    foreach ($match in $sceneConstantMatches) {
        $sceneConstantToPath[$match.Groups[1].Value] = $match.Groups[2].Value
    }

    $indexToScene = @{}
    $registeredScenePaths = New-Object System.Collections.Generic.HashSet[string]
    foreach ($constantName in $sceneConstantToPath.Keys) {
        $scenePath = $sceneConstantToPath[$constantName]
        [void]$registeredScenePaths.Add($scenePath)
        $fullScenePath = Convert-ResPathToFullPath $scenePath
        if ($fullScenePath -eq "" -or -not (Test-Path -LiteralPath $fullScenePath)) {
            Add-ValidationError "SaveManager registers missing level scene: $scenePath"
            continue
        }

        $entryMatch = [regex]::Match($saveManagerContent, "(?ms)$([regex]::Escape($constantName)):\s*\{(.*?)\n\t\},")
        if (-not $entryMatch.Success) {
            Add-ValidationError "SaveManager level scene $scenePath is missing a LEVEL_DISPLAY_REGISTRY entry."
            continue
        }

        $entryBody = $entryMatch.Groups[1].Value
        $indexMatch = [regex]::Match($entryBody, '"level_index":\s*([0-9]+)')
        if (-not $indexMatch.Success) {
            Add-ValidationError "SaveManager level scene $scenePath is missing level_index."
        } else {
            $levelIndex = [int]::Parse($indexMatch.Groups[1].Value)
            if ($levelIndex -le 0) {
                Add-ValidationError "SaveManager level scene $scenePath has non-positive level_index $levelIndex."
            } elseif ($indexToScene.ContainsKey($levelIndex)) {
                Add-ValidationError "SaveManager level_index $levelIndex is duplicated by $scenePath and $($indexToScene[$levelIndex])."
            } else {
                $indexToScene[$levelIndex] = $scenePath
            }
        }

        foreach ($requiredField in @("display_name", "map_region_id")) {
            $fieldMatch = [regex]::Match($entryBody, '"' + $requiredField + '":\s*"([^"]*)"')
            if (-not $fieldMatch.Success -or $fieldMatch.Groups[1].Value -eq "") {
                Add-ValidationError "SaveManager level scene $scenePath has an empty or missing $requiredField."
            }
        }

        $categoryMatch = [regex]::Match($entryBody, '"category":\s*(?:"([^"]+)"|([A-Z0-9_]+))')
        if (-not $categoryMatch.Success) {
            Add-ValidationError "SaveManager level scene $scenePath is missing category."
        } else {
            $category = $categoryMatch.Groups[1].Value
            if ($category -eq "") {
                $categoryConstant = $categoryMatch.Groups[2].Value
                $category = [string]$categoryValues[$categoryConstant]
            }
            if ($category -eq "" -or -not $allowedCategories.Contains($category)) {
                Add-ValidationError "SaveManager level scene $scenePath has invalid category '$($categoryMatch.Value)'."
            }
        }

        $bossMatch = [regex]::Match($entryBody, '"is_boss_level":\s*(true|false)')
        if (-not $bossMatch.Success) {
            Add-ValidationError "SaveManager level scene $scenePath is missing is_boss_level."
        }
    }

    $levelsRoot = Join-Path $projectRoot "scenes\levels"
    if (Test-Path -LiteralPath $levelsRoot) {
        $levelScenes = Get-ChildItem -Path $levelsRoot -Filter "*.tscn" -File
        foreach ($scene in $levelScenes) {
            $relativeScenePath = "res://scenes/levels/$($scene.Name)"
            if (-not $registeredScenePaths.Contains($relativeScenePath)) {
                Add-ValidationError "$relativeScenePath is missing from SaveManager.LEVEL_DISPLAY_REGISTRY."
            }

            $sceneContent = Get-Content -LiteralPath $scene.FullName -Raw
            $expectedRootName = "Level-$($scene.BaseName)"
            if ($sceneContent -notmatch "\[node name=`"$([regex]::Escape($expectedRootName))`" type=`"Node2D`"\]") {
                Add-ValidationError "$relativeScenePath root node should be '$expectedRootName'."
            }
        }
    }
}

foreach ($scene in $sceneFiles) {
    $content = Get-Content -LiteralPath $scene.FullName -Raw
    $relative = Get-RelativePath $scene.FullName
    $routeExitScriptIds = New-Object System.Collections.Generic.List[string]
    $resourceMatches = [regex]::Matches($content, '\[ext_resource[^\]]*path="res://scripts/interactions/RouteExitArea\.gd"[^\]]*id="([^"]+)"[^\]]*\]')
    foreach ($match in $resourceMatches) {
        $routeExitScriptIds.Add([regex]::Escape($match.Groups[1].Value))
    }

    $routeIds = @{}
    $nodeBlocks = [regex]::Matches($content, '(?ms)\[node[^\]]+\].*?(?=\r?\n\[node|\z)')
    foreach ($nodeBlockMatch in $nodeBlocks) {
        $block = $nodeBlockMatch.Value
        $nodeName = "<unknown>"
        $nodeNameMatch = [regex]::Match($block, '\[node name="([^"]+)"')
        if ($nodeNameMatch.Success) {
            $nodeName = $nodeNameMatch.Groups[1].Value
        }

        $nodeParent = ""
        $nodeParentMatch = [regex]::Match($block, '\[node[^\]]*parent="([^"]+)"')
        if ($nodeParentMatch.Success) {
            $nodeParent = $nodeParentMatch.Groups[1].Value
        }

        $isRouteExit = $false
        foreach ($resourceId in $routeExitScriptIds) {
            if ($block -match "script = ExtResource\(`"$resourceId`"\)") {
                $isRouteExit = $true
                break
            }
        }

        $looksLikeRouteExit = $nodeName -match 'Exit$' -and $nodeParent -eq 'PlayableWorld/Environment/Interactables/RouteExits'
        if ($looksLikeRouteExit -and -not $isRouteExit) {
            Add-ValidationError "$relative route exit '$nodeName' is under PlayableWorld/Environment/Interactables/RouteExits but does not use RouteExitArea.gd."
            continue
        }

        if (-not $isRouteExit) {
            continue
        }

        $routeId = ""
        $routeIdMatch = [regex]::Match($block, '(?m)^route_id = "([^"]*)"')
        if ($routeIdMatch.Success) {
            $routeId = $routeIdMatch.Groups[1].Value
        }
        if ($routeId -eq "") {
            Add-ValidationError "$relative route exit '$nodeName' has an empty route_id."
        } elseif ($routeIds.ContainsKey($routeId)) {
            Add-ValidationError "$relative has duplicate route_id '$routeId' on '$nodeName' and '$($routeIds[$routeId])'."
        } else {
            $routeIds[$routeId] = $nodeName
        }

        $destinationScenePath = ""
        $destinationSceneMatch = [regex]::Match($block, '(?m)^destination_scene_path = "([^"]*)"')
        if ($destinationSceneMatch.Success) {
            $destinationScenePath = $destinationSceneMatch.Groups[1].Value
        }

        $entryMarkerPath = ""
        $entryMarkerMatch = [regex]::Match($block, '(?m)^destination_entry_marker_path = NodePath\("([^"]*)"\)')
        if ($entryMarkerMatch.Success) {
            $entryMarkerPath = $entryMarkerMatch.Groups[1].Value
        }

        if ($destinationScenePath -ne "") {
            if (-not $destinationScenePath.EndsWith(".tscn")) {
                Add-ValidationError "$relative route exit '$nodeName' destination_scene_path is not a .tscn: $destinationScenePath"
            } else {
                $destinationFullPath = Convert-ResPathToFullPath $destinationScenePath
                if ($destinationFullPath -eq "" -or -not (Test-Path -LiteralPath $destinationFullPath)) {
                    Add-ValidationError "$relative route exit '$nodeName' points to missing destination scene: $destinationScenePath"
                }
            }

            if ($entryMarkerPath -eq "") {
                Add-ValidationError "$relative route exit '$nodeName' has a destination scene but no destination_entry_marker_path."
            } elseif ($entryMarkerPath -notmatch '^PlayableWorld/Markers/Entrances/') {
                Add-ValidationWarning "$relative route exit '$nodeName' destination_entry_marker_path should use PlayableWorld/Markers/Entrances/..."
            }
        }
    }
}

$bansheeVillageFlowPath = Join-Path $projectRoot "scripts\levels\banshee_village\BansheeVillageFlowController.gd"
if (Test-Path -LiteralPath $bansheeVillageFlowPath) {
    $flowContent = Get-Content -LiteralPath $bansheeVillageFlowPath -Raw
    $storyMarkerExports = [regex]::Matches($flowContent, '(?m)^@export var ((?:final_[A-Za-z0-9_]*|[A-Za-z0-9_]*story[A-Za-z0-9_]*)marker_path): NodePath = NodePath\("([^"]*)"\)')
    foreach ($match in $storyMarkerExports) {
        $exportName = $match.Groups[1].Value
        $markerPath = $match.Groups[2].Value
        if ($markerPath -match 'PlayableWorld/Markers/Entrances/') {
            Add-ValidationWarning "BansheeVillageFlowController.$exportName points to an entrance marker. Story staging markers should use PlayableWorld/Markers/StoryPositions/..."
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
