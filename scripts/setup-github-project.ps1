#Requires -Version 5.1
<#
.SYNOPSIS
  Crea repo meta, GitHub Project v2, milestones, labels e issues completas MedEstetica.
#>
param(
    [switch]$DryRun,
    [switch]$SkipRepoCreate,
    [switch]$SkipIssues,
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
    if (-not $candidates) { throw "GitHub CLI (gh) no encontrado. Instala: winget install GitHub.cli" }
    return $candidates
}

function Invoke-Gh {
    param([string[]]$GhArgs)
    if ($DryRun) {
        Write-Host "[dry-run] gh $($GhArgs -join ' ')" -ForegroundColor DarkGray
        return $null
    }
    $gh = Get-GhExe
    $output = & $gh @GhArgs 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh $($GhArgs -join ' ') failed: $output" }
    return ($output | Out-String).Trim()
}

function Ensure-GhAuth {
    $gh = Get-GhExe
    & $gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "No hay sesion en GitHub CLI. Ejecuta: gh auth login"
    }
}

function Ensure-Labels {
    param([string]$Repo, [string[]]$Labels)
    foreach ($label in $Labels) {
        try {
            $color = switch -Regex ($label) {
                'status:resolved|done' { '0E8A16' }
                'status:pending' { 'D93F0B' }
                'status:optional' { 'FBCA04' }
                'type:bugfix' { 'B60205' }
                'type:improvement' { 'C5DEF5' }
                'type:epic' { '5319E7' }
                'priority:P0' { 'B60205' }
                default { '1D76DB' }
            }
            Invoke-Gh @("label", "create", $label, "--repo", "$Owner/$Repo", "--force", "--color", $color) | Out-Null
        } catch {
            Write-Warning "Label $label en ${Repo}: $_"
        }
    }
}

function Ensure-Milestones {
    param([string]$Repo, [string[]]$Titles)
    foreach ($title in $Titles) {
        try {
            Invoke-Gh @("api", "repos/$Owner/$Repo/milestones", "-f", "title=$title", "-f", "state=open") | Out-Null
        } catch {
            Write-Warning "Milestone $title en ${Repo}: $_"
        }
    }
}

function Find-IssueByTitle {
    param([string]$Repo, [string]$Title)
    if ($DryRun) { return $null }
    $q = [uri]::EscapeDataString("repo:$Owner/$Repo is:issue `"$Title`"")
    $json = Invoke-Gh @("search", "issues", $q, "--json", "url,number,title", "--jq", ".items[0]")
    if ($json -and $json -ne "null") { return ($json | ConvertFrom-Json) }
    return $null
}

function New-ProjectIssue {
    param(
        [object]$Item,
        [hashtable]$RepoMap,
        [hashtable]$IssueIndex
    )
    $repoName = $RepoMap[$Item.repo]
    if (-not $repoName) { throw "Repo desconocido: $($Item.repo)" }

    $existing = Find-IssueByTitle -Repo $repoName -Title $Item.title
    if ($existing) {
        Write-Host "  (existe) #$($existing.number) $($Item.title)" -ForegroundColor DarkGray
        $IssueIndex[$Item.title] = $existing
        return $existing.url
    }

    $labels = @($Item.labels)
    if ($Item.priority) { $labels += "priority:$($Item.priority)" }
    if ($Item.milestone) { $labels += "milestone:$($Item.milestone -replace '[^a-zA-Z0-9]+','-')" }
    if ($Item.kind) { $labels += "type:$($Item.kind)" }

    $extra = @()
    if ($Item.parent) { $extra += "**Parent:** $($Item.parent)" }
    if ($Item.parentEpic) { $extra += "**Epic:** $($Item.parentEpic)" }
    if ($Item.source) { $extra += "**Source:** $($Item.source)" }

    $body = @(
        $(if ($Item.body) { $Item.body } else { "" }),
        "",
        ($extra -join "`n"),
        "---",
        "**Kind:** $($Item.kind)",
        "**Area:** $($Item.area)",
        "**Repo:** $($Item.repo)",
        "**Milestone:** $($Item.milestone)",
        "**Priority:** $($Item.priority)",
        "**Status:** $($Item.status)",
        "",
        "_Generado desde .github/project/tasks.json (skill MedEstetica Obsidian)._"
    ) -join "`n"

    $issueArgs = @("issue", "create", "--repo", "$Owner/$repoName", "--title", $Item.title, "--body", $body)
    if ($Item.milestone) { $issueArgs += @("--milestone", $Item.milestone) }
    foreach ($label in ($labels | Select-Object -Unique)) {
        if ($label) { $issueArgs += @("--label", $label) }
    }

    $url = Invoke-Gh $issueArgs
    if ($url) {
        $number = ($url -split '/')[-1]
        $IssueIndex[$Item.title] = [pscustomobject]@{ url = $url; number = [int]$number }
        if ($Item.status -eq "Done") {
            Invoke-Gh @("issue", "close", "$number", "--repo", "$Owner/$repoName", "--reason", "completed") | Out-Null
        }
    }
    return $url
}

function Add-ToProject {
    param([int]$ProjectNumber, [string]$Url)
    if ($DryRun -or -not $Url) { return }
    try {
        Invoke-Gh @("project", "item-add", "$ProjectNumber", "--owner", $Owner, "--url", $Url) | Out-Null
    } catch {
        Write-Warning "No se pudo agregar al project: $Url"
    }
}

# --- Main ---
Write-Host "MedEstetica SaaS - setup GitHub Project (completo)" -ForegroundColor Cyan
if (-not $DryRun) { Ensure-GhAuth }

$manifest = Get-Content "$Root\repos.manifest.json" -Raw | ConvertFrom-Json
$tasksDef = Get-Content "$Root\.github\project\tasks.json" -Raw | ConvertFrom-Json
$repoMap = @{}
foreach ($r in $manifest.repos) { $repoMap[$r.id] = $r.name }

$allLabels = @(
    "epic", "checklist-obsidian", "backlog", "done", "performance", "testing", "integration",
    "type:epic", "type:feature", "type:bugfix", "type:task", "type:subtask", "type:improvement",
    "status:resolved", "status:pending", "status:optional",
    "area:landing", "area:dashboard", "area:agenda", "area:inventario", "area:ordenes",
    "area:tratamientos", "area:media", "area:infra", "area:qa", "area:whatsapp",
    "priority:P0", "priority:P1", "priority:P2", "priority:P3"
)

# 1) Repo meta
$platformRepo = $manifest.repos | Where-Object { $_.id -eq "platform" } | Select-Object -First 1
if (-not $SkipRepoCreate) {
    $exists = $null
    try { $exists = Invoke-Gh @("repo", "view", "$Owner/$($platformRepo.name)", "--json", "name", "-q", ".name") } catch { $exists = $null }
    if (-not $exists -and -not $DryRun) {
        Write-Host "Creando repositorio $($platformRepo.name)..." -ForegroundColor Yellow
        Invoke-Gh @(
            "repo", "create", "$Owner/$($platformRepo.name)",
            "--public", "--description", $manifest.description,
            "--source", $Root, "--remote", "origin", "--push"
        ) | Out-Null
    } elseif ($exists) {
        Write-Host "Repo $($platformRepo.name) ya existe." -ForegroundColor Green
        if (-not $DryRun) {
            try { git push -u origin dev 2>&1 | Out-Null } catch { Write-Warning "Push pendiente: git push -u origin dev" }
        }
    } else {
        Write-Host "[dry-run] Crearia repo $($platformRepo.name)" -ForegroundColor DarkGray
    }
}

# 2) Labels y milestones
$milestones = @($tasksDef.milestones)
foreach ($repo in $manifest.repos) {
    Write-Host "Labels + milestones en $($repo.name)..." -ForegroundColor DarkCyan
    Ensure-Labels -Repo $repo.name -Labels $allLabels
    Ensure-Milestones -Repo $repo.name -Titles $milestones
}

# 3) GitHub Project
$projectTitle = $tasksDef.projectTitle
$projectUrl = $null
$projectNumber = $null
$coreRepoIds = @("platform", "backend", "frontend", "docs")

if (-not $DryRun) {
    $existingProjects = Invoke-Gh @("project", "list", "--owner", $Owner, "--format", "json")
    $match = @($existingProjects | ConvertFrom-Json) | Where-Object { $_.title -eq $projectTitle } | Select-Object -First 1
    if ($match) {
        $projectNumber = $match.number
        $projectUrl = $match.url
        Write-Host "Project existente #$projectNumber -> $projectUrl" -ForegroundColor Yellow
    } else {
        $projectJson = Invoke-Gh @("project", "create", "--owner", $Owner, "--title", $projectTitle, "--format", "json")
        $project = $projectJson | ConvertFrom-Json
        $projectNumber = $project.number
        $projectUrl = $project.url
        Write-Host "Project creado #$projectNumber -> $projectUrl" -ForegroundColor Green
    }
    foreach ($repo in ($manifest.repos | Where-Object { $coreRepoIds -contains $_.id })) {
        try {
            Invoke-Gh @("project", "link", "$projectNumber", "--owner", $Owner, "--repo", "$Owner/$($repo.name)") | Out-Null
            Write-Host "  Vinculado: $($repo.name)" -ForegroundColor DarkCyan
        } catch { Write-Warning "Link $($repo.name): $_" }
    }
} else {
    Write-Host "[dry-run] Project '$projectTitle' + repos: $($coreRepoIds -join ', ')" -ForegroundColor DarkGray
}

# 4) Issues
$created = @()
$issueIndex = @{}
if (-not $SkipIssues) {
    $allItems = @()
    if ($tasksDef.epics) { $allItems += $tasksDef.epics }
    if ($tasksDef.tasks) { $allItems += $tasksDef.tasks }
    if ($tasksDef.subtasks) { $allItems += $tasksDef.subtasks }
    if ($tasksDef.improvements) { $allItems += $tasksDef.improvements }

    foreach ($item in $allItems) {
        Write-Host "Issue: $($item.title)" -ForegroundColor White
        $url = New-ProjectIssue -Item $item -RepoMap $repoMap -IssueIndex $issueIndex
        if ($url) {
            $created += $url
            Add-ToProject -ProjectNumber $projectNumber -Url $url
        }
    }
}

# 5) Resumen
$allTasks = @($tasksDef.tasks) + @($tasksDef.subtasks) + @($tasksDef.improvements)
$doneCount = @($allTasks | Where-Object { $_.status -eq "Done" }).Count
$todoCount = @($allTasks | Where-Object { $_.status -eq "Todo" }).Count
$inProgressCount = @($allTasks | Where-Object { $_.status -eq "In Progress" }).Count
$improvementCount = @($tasksDef.improvements).Count

$summary = @"
# Ultima ejecucion setup-github-project

- Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm')
- Project: $projectUrl
- Issues procesadas: $($created.Count)
- Resueltas (Done): $doneCount
- En progreso: $inProgressCount
- Pendientes (Todo): $todoCount
- Mejoras opcionales: $improvementCount

## Vistas recomendadas en GitHub
1. Por estado (Status / labels status:*)
2. Por modulo (labels area:*)
3. Por tipo (labels type:feature, type:bugfix, type:improvement)
4. Roadmap por milestone
"@

$summaryPath = Join-Path $Root ".github\project\last-run.md"
if (-not $DryRun) { Set-Content -Path $summaryPath -Value $summary -Encoding UTF8 }

Write-Host ""
Write-Host "=== Resumen ===" -ForegroundColor Cyan
Write-Host "Issues: $($created.Count) | Done: $doneCount | In Progress: $inProgressCount | Todo: $todoCount | Mejoras: $improvementCount"
if ($projectUrl) { Write-Host "Tablero: $projectUrl" -ForegroundColor Green }
Write-Host "Listo." -ForegroundColor Green
