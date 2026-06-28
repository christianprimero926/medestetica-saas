# MedEstética SaaS

Plataforma SaaS multi-tenant para clínicas de medicina estética. Consolida agendamiento, inventario, catálogo/carrito y administración con roles y permisos dinámicos, personalización de marca por cliente y despliegue económico local o en la nube.

## Componentes

| Componente | Stack | Puerto |
|------------|-------|--------|
| **Backend** | NestJS + Prisma + PostgreSQL | 3001 |
| **Frontend** | Next.js 14 + Tailwind CSS | 3000 |
| **Base de datos** | PostgreSQL 16 (Docker) | 54333 |
| **WhatsApp Bot** | Repo hermano [`whatsapp-cloud-bot`](../whatsapp-cloud-bot) | 3002 |

## Inicio rápido (Docker)

```bash
# Desde la raíz del proyecto
docker compose up -d

# Backend: http://localhost:3001/api/docs
# Frontend: http://localhost:3000
```

## Inicio local (desarrollo)

```bash
# 1. Base de datos
docker compose up -d postgres

# Nota: PostgreSQL del proyecto usa puerto 54333 (evita conflicto con Postgres local)

# 2. Backend
cd backend
cp .env.example .env
npm install
npx prisma migrate dev
npm run seed
npm run start:dev

# 3. Frontend (otra terminal)
cd frontend
cp .env.example .env.local
npm install
npm run dev
```

## Credenciales demo

Interfaz de login: http://localhost:3000/login

| Rol | Email | Contraseña | Tenant slug |
|-----|-------|------------|-------------|
| Super Admin | super@medestetica.app | Demo1234! | *(marcar checkbox "Acceso Super Admin" en login)* |
| Admin | admin@bellabeauty.demo | Demo1234! | `bella-beauty` |
| Supervisor | supervisor@bellabeauty.demo | Demo1234! | `bella-beauty` |
| Cliente | cliente@email.com | Demo1234! | `bella-beauty` |

**Notas:**
- Todos los usuarios de tenant requieren el slug `bella-beauty` en el campo "Clínica (tenant slug)" del login.
- Super Admin no usa tenant slug; activa el checkbox en la pantalla de login.
- Contraseña común de demo: `Demo1234!`

## URLs del tenant demo (Bella Beauty)

| Vista | URL |
|-------|-----|
| Portal pacientes | http://localhost:3000/c/bella-beauty |
| Panel admin (dueño) | http://localhost:3000/login?tenant=bella-beauty |

Ver guía completa: [docs/VISTAS_TENANT.md](docs/VISTAS_TENANT.md)

## Repositorios Git

| Repo | Descripción |
|------|-------------|
| [medestetica-saas](https://github.com/christianprimero926/medestetica-saas) | Docker, scripts y tablero GitHub Project |
| [medestetica-saas-backend](https://github.com/christianprimero926/medestetica-saas-backend) | API NestJS |
| [medestetica-saas-frontend](https://github.com/christianprimero926/medestetica-saas-frontend) | Panel Next.js |
| [medestetica-saas-docs](https://github.com/christianprimero926/medestetica-saas-docs) | Documentación |

Tablero de progreso (GitHub Project + issues): [docs/GITHUB_PROJECT.md](docs/GITHUB_PROJECT.md)

## Documentación

- [Arquitectura general](docs/ARCHITECTURE.md)
- [Seguridad y estado técnico](docs/SEGURIDAD.md)
- [Plan MVP — prueba con el cliente](docs/PLAN_MVP_TEST.md)
- [GitHub Project / roadmap](docs/GITHUB_PROJECT.md)
- [Credenciales demo](docs/CREDENCIALES_DEMO.md)
- [Vistas por tenant (admin vs pacientes)](docs/VISTAS_TENANT.md)
- [Propuesta comercial tipo](docs/PROPUESTA_COMERCIAL_TIPO.md)
- [Acuerdo embajador / referidos](docs/ACUERDO_EMBAJADOR_REFERIDOS.md)
- [Chatbot WhatsApp](../whatsapp-cloud-bot) (`whatsapp-cloud-bot`, adapter `medestetica`)
- [Despliegue económico / VPS](docs/DEPLOYMENT.md)
- [Migración a AWS](docs/AWS_MIGRATION.md)
- [Módulos](docs/modules/)

## Estructura

```
medestetica-saas/
├── backend/          # API REST NestJS
├── frontend/         # Panel web Next.js
├── docs/             # Documentación por módulo
└── docker-compose.yml
```
