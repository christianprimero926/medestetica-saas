#!/usr/bin/env bash
# Despliegue/actualización en el VPS con imágenes precompiladas de GHCR.
# Uso en el servidor:  ./scripts/deploy.sh v1.2.0
#                      ./scripts/deploy.sh dev
set -euo pipefail

TAG="${1:-}"
COMPOSE="docker compose -f docker-compose.prod.yml --env-file .env.production"

cd "$(dirname "$0")/.."

if [ -n "$TAG" ]; then
  # Fija IMAGE_TAG en .env.production sin duplicar la línea
  if grep -q '^IMAGE_TAG=' .env.production; then
    sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=$TAG/" .env.production
  else
    echo "IMAGE_TAG=$TAG" >> .env.production
  fi
  echo ">> Desplegando IMAGE_TAG=$TAG"
fi

echo ">> Bajando imágenes..."
$COMPOSE pull

echo ">> Levantando (migraciones se aplican al arrancar el backend)..."
$COMPOSE up -d

echo ">> Estado:"
$COMPOSE ps
echo ">> Listo. Verifica https://\$APP_DOMAIN/api/docs"
