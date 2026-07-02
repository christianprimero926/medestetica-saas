# Backup diario de la BD de MedEstetica (pg_dump formato custom).
# Destino por defecto: OneDrive (sincroniza offsite automaticamente).
# Uso manual:  powershell -NoProfile -ExecutionPolicy Bypass -File scripts\backup-db.ps1
# Programado:  tarea "MedEstetica DB Backup" (diaria 08:00, ver docs/PLAN_MVP_TEST.md)
param(
  [string]$BackupDir = "C:\Users\chris\OneDrive\Backups\medestetica",
  [int]$RetentionDays = 14
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BackupDir)) {
  New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
}

$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$file = Join-Path $BackupDir "medestetica_$stamp.dump"

# Dump dentro del contenedor y copia al host
docker exec medestetica-db pg_dump -U medestetica -d medestetica -F c -f /tmp/backup.dump
if ($LASTEXITCODE -ne 0) { throw "pg_dump fallo (contenedor medestetica-db corriendo?)" }
docker cp medestetica-db:/tmp/backup.dump $file
if ($LASTEXITCODE -ne 0) { throw "docker cp fallo" }
docker exec medestetica-db rm -f /tmp/backup.dump

# Retencion: borra backups con mas de $RetentionDays dias
Get-ChildItem $BackupDir -Filter "medestetica_*.dump" |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
  Remove-Item -Force

$size = [math]::Round((Get-Item $file).Length / 1KB, 1)
Write-Output "Backup OK: $file ($size KB)"
Write-Output "Restaurar: docker exec -i medestetica-db pg_restore -U medestetica -d medestetica --clean --if-exists < $file"
