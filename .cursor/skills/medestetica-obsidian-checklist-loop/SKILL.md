---
name: medestetica-obsidian-checklist-loop
description: >-
  Ejecuta el checklist de Obsidian «Cosas por hacer.md» de MedEstética SaaS en
  loop: una tarea sin marcar por iteración, verificación local, marcar [x], y
  documentar hallazgos. Usar cuando el usuario pida corregir el checklist de
  Obsidian, tareas pendientes MedEstética, o loop de mejoras del SaaS.
---

# MedEstética — Loop checklist Obsidian

## Rutas fijas

| Recurso | Ruta |
|---------|------|
| Checklist | `C:\Users\chris\OneDrive\Documentos\Obsidian Vault\MedEstética SaaS\Cosas por hacer.md` |
| Mejoras (crear/actualizar) | `C:\Users\chris\OneDrive\Documentos\Obsidian Vault\MedEstética SaaS\Mejoras detectadas.md` |
| Monorepo | `d:\Proyectos\medestetica-saas` |
| Frontend | puerto **3000** |
| Backend | puerto **3001** |
| PostgreSQL | puerto **54333** |

## Reglas de producto

1. **Nada hardcodeado**: textos de negocio, WhatsApp, porcentajes de oferta, duraciones, etc. → parametrizaciones/BD (`tenant parametrizations`, catálogos, seeds).
2. **Una tarea por iteración**: implementar → verificar → marcar `[x]` en Obsidian → anotar en Mejoras si aplica → siguiente.
3. **No pausar el loop**: no preguntar al usuario qué tarea sigue; ejecutar todas las `- [ ]` hasta terminar salvo error bloqueante.
4. **No marcar sin verificar**: al menos build/lint del área tocada + app corriendo o endpoint probado.
5. **Commits**: solo si el usuario lo pide.

## Loop por iteración

```
1. Leer Cosas por hacer.md → primera línea con `- [ ]`
2. Entender alcance (frontend/backend/ambos)
3. Implementar cambio mínimo correcto
4. Verificar:
   - npm run build o lint en módulo afectado
   - Si servidores caídos: docker compose up + backend dev + frontend dev
   - Smoke: curl o navegación lógica del cambio
5. En Obsidian: cambiar `- [ ]` → `- [x]` solo esa tarea
6. En Mejoras detectadas.md: bullet si encontraste deuda técnica o idea
7. Continuar con la siguiente `- [ ]`
```

## Arranque local (si no hay servidores)

```powershell
cd d:\Proyectos\medestetica-saas
docker compose up -d
cd backend; npm run start:dev
# otra terminal
cd frontend; npm run dev
```

Demo: `admin@bellabeauty.demo` / `Demo1234!` / tenant `bella-beauty`

## Orden sugerido (dependencias)

1. Landing WhatsApp (parametrizado)
2. Filtros de gráficos (completar módulos faltantes)
3. Dashboard/agenda tablas + paginación
4. Inventario (gráficos, top 5, limpieza secciones)
5. Órdenes tabla
6. Tratamientos CRUD
7. Agenda (picker, manual, recurrente, leads tabla)
8. Biblioteca imágenes / media
9. Performance (SWR/reactivo) — transversal, al final o por página

## Plantilla Mejoras detectadas.md

```markdown
# Mejoras detectadas (agente)

Actualizado: yyyy-MM-dd

## Durante el loop
- [fecha] **Área**: descripción breve

## Backlog sugerido
- ...
```
