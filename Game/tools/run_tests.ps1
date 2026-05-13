param(
    [string]$GodotExecutable = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $projectRoot

function Invoke-Step([string]$Name, [scriptblock]$Command) {
    Write-Host ""
    Write-Host "== $Name ==" -ForegroundColor Cyan
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function Resolve-GodotExecutable {
    param([string]$ExplicitPath)

    if ($ExplicitPath -ne "") {
        if (Test-Path -LiteralPath $ExplicitPath) {
            return (Resolve-Path -LiteralPath $ExplicitPath).Path
        }
        $explicitCommand = Get-Command $ExplicitPath -ErrorAction SilentlyContinue
        if ($explicitCommand -ne $null) {
            return $explicitCommand.Source
        }
        throw "Godot executable was not found: $ExplicitPath"
    }

    foreach ($candidate in @("godot4_console", "godot4", "godot_console", "godot")) {
        $command = Get-Command $candidate -ErrorAction SilentlyContinue
        if ($command -ne $null) {
            return $command.Source
        }
    }

    throw "Could not find Godot on PATH. Pass -GodotExecutable with the Godot executable path."
}

Invoke-Step "Project structure validation" {
    powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "validate_project_structure.ps1")
}

$godot = Resolve-GodotExecutable -ExplicitPath $GodotExecutable
Invoke-Step "Godot headless tests" {
    & $godot --headless --path $projectRoot --script "res://tests/test_runner.gd"
}

Invoke-Step "Git diff whitespace check" {
    git -C $repoRoot diff --check
}

Write-Host ""
Write-Host "All tests passed." -ForegroundColor Green
