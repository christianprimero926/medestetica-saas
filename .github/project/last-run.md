# Ultima ejecucion setup-github-project

- Fecha: 2026-06-24
- **Tablero principal:** https://github.com/users/christianprimero926/projects/6
- Repos vinculados: medestetica-saas, medestetica-saas-backend, medestetica-saas-frontend, medestetica-saas-docs
- Issues totales en GitHub: ~59

## Estructura del tablero

| Tipo | Labels | Cantidad aprox. |
|------|--------|-----------------|
| Epics | `type:epic` | 8 |
| Features / bugfixes resueltas | `status:resolved` | ~35 |
| Pendientes checklist | `status:pending`, `checklist-obsidian` | ~10 |
| Subtareas | `type:subtask` | 6 |
| Mejoras opcionales | `type:improvement`, `status:optional` | 10 |

## Vistas recomendadas en GitHub Projects

1. **Board por estado** — filtrar `status:resolved` vs `status:pending` vs `status:optional`
2. **Por modulo** — labels `area:agenda`, `area:dashboard`, etc.
3. **Por repo** — filtrar por repositorio vinculado
4. **Roadmap** — labels `milestone:M1-MVP-operativo` ... `M4-Integraciones`

## Pendientes criticos (Obsidian)

- Agenda: reprogramar citas (+ 3 subtareas)
- Agenda: estado en curso (+ 3 subtareas)

## Fuente de verdad local

- Definicion: `.github/project/tasks.json`
- Checklist: Obsidian `Cosas por hacer.md`
- Mejoras: Obsidian `Mejoras detectadas.md`

## Re-sincronizar

```powershell
cd d:\Proyectos\medestetica-saas
.\scripts\setup-github-project.ps1 -SkipRepoCreate
```
