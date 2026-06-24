#Requires -Version 5.1
<#
.SYNOPSIS
  Crea el repositorio meta, el GitHub Project v2 y las issues de los 3 repos MedEstética.

.DESCRIPTION
  Lee repos.manifest.json y .github/project/tasks.json (sincronizado con Obsidian).
  Requiere: GitHub CLI autenticado (`gh auth login`).

.EXAMPLE
  .\scripts\setup-github-project.ps1
  .\scripts\setup-github-project.ps1 -DryRun
  .\scripts\setup-github-project.ps1 -SkipRepoCreate
#>
param(
    [switch]$DryRun,
    [switch]$SkipRepoCreate,
    [string]$Owner = "christianprimero926"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Get-GhExe {
    $candidates = @(
        (Get-Command gh -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        "$env:ProgramFiles\GitHub CLI\gh.exe",
        "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
    ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique -First 1
    if (-not $candidates) {
        throw "GitHub CLI (gh) no encontrado. Instala con: winget install GitHub.cli"
    }
    return $candidates
}

function Invoke-Gh {
    param([string[]]$GhArgs)
    $gh = Get-GhExe
    if ($DryRun) {
        Write-Host "[dry-run] gh $($GhArgs -join ' ')" -ForegroundColor DarkGray
        return $null
    }
    $output = & $gh @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "gh $($GhArgs -join ' ') failed: $output"
    }
    return ($output | Out-String).Trim()
}

function Ensure-GhAuth {
    $gh = Get-GhExe
    & $gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw @"
No hay sesión en GitHub CLI.
Ejecuta: gh auth login
Luego vuelve a correr: .\scripts\setup-github-project.ps1
"@
    }
}

function Ensure-Labels {
    param(
        [string]$Repo,
        [string[]]$Labels
    )
    foreach ($label in $Labels) {
        try {
            Invoke-Gh @("label", "create", $label, "--repo", "$Owner/$Repo", "--force", "--color", "1D76DB") | Out-Null
        } catch {
            Write-Warning "Label $label en ${Repo}: $_"
        }
    }
}

function New-ProjectIssue {
    param(
        [object]$Item,
        [hashtable]$RepoMap
    )
    $repoName = $RepoMap[$Item.repo]
    if (-not $repoName) { throw "Repo desconocido: $($Item.repo)" }

    $labels = @($Item.labels)
    if ($Item.priority) { $labels += "priority:$($Item.priority)" }
    if ($Item.milestone) { $labels += "milestone:$($Item.milestone -replace '[^a-zA-Z0-9]+','-')" }

  $body = @(
        $Item.body,
        "",
        "---",
        "**Area:** $($Item.area)",
        "**Repo:** $($Item.repo)",
        "**Milestone:** $($Item.milestone)",
        "**Priority:** $($Item.priority)",
        "**Status:** $($Item.status)",
        "",
        '_Generado desde .github/project/tasks.json (skill MedEstética Obsidian)._'
    ) -join "`n"

    $issueArgs = @(
        "issue", "create",
        "--repo", "$Owner/$repoName",
        "--title", $Item.title,
        "--body", $body
    )
    foreach ($label in ($labels | Select-Object -Unique)) {
        if ($label) { $issueArgs += @("--label", $label) }
    }

    $url = Invoke-Gh $issueArgs
    if ($Item.status -eq "Done" -and $url) {
        $number = ($url -split '/')[-1]
        Invoke-Gh @("issue", "close", $number, "--repo", "$Owner/$repoName", "--reason", "completed") | Out-Null
    }
    return $url
}

# --- Main ---
Write-Host "MedEstetica SaaS - setup GitHub Project" -ForegroundColor Cyan
if (-not $DryRun) { Ensure-GhAuth }

$manifest = Get-Content "$Root\repos.manifest.json" -Raw | ConvertFrom-Json
$tasksDef = Get-Content "$Root\.github\project\tasks.json" -Raw | ConvertFrom-Json
$repoMap = @{}
foreach ($r in $manifest.repos) { $repoMap[$r.id] = $r.name }

# 1) Crear repo meta platform si no existe
$platformRepo = $manifest.repos | Where-Object { $_.id -eq "platform" } | Select-Object -First 1
if (-not $SkipRepoCreate) {
    $exists = $null
    try {
        $exists = Invoke-Gh @("repo", "view", "$Owner/$($platformRepo.name)", "--json", "name", "-q", ".name")
    } catch {
        $exists = $null
    }
    if (-not $exists -and -not $DryRun) {
        Write-Host "Creando repositorio $($platformRepo.name)..." -ForegroundColor Yellow
        Invoke-Gh @(
            "repo", "create", "$Owner/$($platformRepo.name)",
            "--public",
            "--description", $manifest.description,
            "--source", $Root,
            "--remote", "origin",
            "--push"
        ) | Out-Null
    } elseif (-not $exists) {
        Write-Host "[dry-run] Crearía repo $($platformRepo.name) y push inicial" -ForegroundColor DarkGray
    } else {
        Write-Host "Repo $($platformRepo.name) ya existe." -ForegroundColor Green
        if (-not (Test-Path "$Root\.git")) {
            git init | Out-Null
            git branch -M dev
            git remote add origin $platformRepo.url 2>$null
        }
    }
}

# 2) Labels en los 3 repos
$allLabels = @("epic", "checklist-obsidian", "backlog", "done", "performance", "testing", "integration",
    "area:landing", "area:dashboard", "area:agenda", "area:inventario", "area:tratamientos", "area:media", "area:infra", "area:qa", "area:whatsapp",
    "priority:P0", "priority:P1", "priority:P2", "priority:P3")
foreach ($repo in $manifest.repos) {
    Write-Host "Labels en $($repo.name)..." -ForegroundColor DarkCyan
    Ensure-Labels -Repo $repo.name -Labels $allLabels
}

# 3) Crear GitHub Project v2 y vincular repos core (backend, frontend, docs) + platform
Write-Host "Creando GitHub Project..." -ForegroundColor Yellow
$projectTitle = $tasksDef.projectTitle
$projectUrl = $null
$projectNumber = $null
$coreRepoIds = @("platform", "backend", "frontend", "docs")
if (-not $DryRun) {
    $projectJson = Invoke-Gh @("project", "create", "--owner", $Owner, "--title", $projectTitle, "--format", "json")
    $project = $projectJson | ConvertFrom-Json
    $projectNumber = $project.number
    $projectUrl = $project.url
    Write-Host "Project #$projectNumber -> $projectUrl" -ForegroundColor Green

    foreach ($repo in ($manifest.repos | Where-Object { $coreRepoIds -contains $_.id })) {
        Write-Host "Vinculando $($repo.name)..." -ForegroundColor DarkCyan
        Invoke-Gh @("project", "link", "$projectNumber", "--owner", $Owner, "--repo", "$Owner/$($repo.name)") | Out-Null
    }
} else {
    Write-Host "[dry-run] Crearía project '$projectTitle' y vincularía repos: $($coreRepoIds -join ', ')" -ForegroundColor DarkGray
}

# 4) Crear epics + tasks como issues y agregar al project
$created = @()
foreach ($item in @($tasksDef.epics) + @($tasksDef.tasks)) {
    Write-Host "Issue: $($item.title)" -ForegroundColor White
    $url = New-ProjectIssue -Item $item -RepoMap $repoMap
    if ($url) {
        $created += $url
        if (-not $DryRun -and $projectNumber) {
            Invoke-Gh @("project", "item-add", "$projectNumber", "--owner", $Owner, "--url", $url) | Out-Null
        }
    }
}

# 5) Resumen local
$summaryPath = Join-Path $Root ".github\project\last-run.md"
$doneCount = @($tasksDef.tasks | Where-Object { $_.status -eq "Done" }).Count
$todoCount = @($tasksDef.tasks | Where-Object { $_.status -eq "Todo" }).Count
$inProgressCount = @($tasksDef.tasks | Where-Object { $_.status -eq "In Progress" }).Count

Write-Host ""
Write-Host "=== Resumen ===" -ForegroundColor Cyan
Write-Host "Issues creadas: $($created.Count)"
Write-Host "Done: $doneCount | In Progress: $inProgressCount | Todo: $todoCount"
if ($projectUrl) { Write-Host "Tablero: $projectUrl" -ForegroundColor Green }
Write-Host "Documentacion: docs/GITHUB_PROJECT.md"

if (-not $DryRun) {
    @"

## Última ejecución del script

- Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- Project: $projectUrl
- Issues creadas: $($created.Count)

"@ | Add-Content -Path $summaryPath -Encoding UTF8
}

Write-Host "Listo." -ForegroundColor Green
