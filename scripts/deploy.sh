#!/usr/bin/env bash
# ============================================================================
# Script de deploy baseado em containers (EAP 3.2.2.1)
# ----------------------------------------------------------------------------
# Atualiza a aplicação no host alvo (EC2) puxando a última imagem publicada no
# Docker Hub e (re)subindo o container via Docker Compose.
#
# É idempotente: pode ser executado quantas vezes for preciso; sempre deixa o
# host rodando a imagem :latest mais recente.
#
# Uso (na EC2, dentro de ~/devops-api):
#   DOCKERHUB_USERNAME=felipezag0 ./scripts/deploy.sh
#
# É chamado automaticamente pelo job "deploy" do pipeline de CD
# (.github/workflows/ci.yml), que exporta DOCKERHUB_USERNAME antes de executar.
#
# Pré-requisitos no host:
#   - Docker + plugin docker compose instalados
#   - docker-compose.yml presente no diretório atual
# Variáveis:
#   - DOCKERHUB_USERNAME : usuário do Docker Hub dono da imagem (default: felipezag0)
# ============================================================================

set -euo pipefail   # aborta em erro, variável indefinida ou falha em pipe

# Usuário do Docker Hub (usado pelo compose para montar o nome da imagem).
export DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-felipezag0}"
IMAGE="${DOCKERHUB_USERNAME}/devops-api:latest"

echo ">> Deploy da devops-api iniciado ($(date '+%Y-%m-%d %H:%M:%S'))"
echo ">> Imagem alvo: ${IMAGE}"

# 1. Puxa a última versão da imagem do registry.
echo ">> [1/4] Baixando a imagem mais recente..."
docker compose pull

# 2. (Re)cria o container com a nova imagem. --remove-orphans limpa serviços
#    antigos; o compose recria apenas o que mudou.
echo ">> [2/4] Subindo o container..."
docker compose up -d --remove-orphans

# 3. Remove imagens antigas/órfãs para não acumular disco na EC2.
echo ">> [3/4] Limpando imagens não utilizadas..."
docker image prune -f

# 4. Valida que a API respondeu após o deploy (health check pós-deploy).
echo ">> [4/4] Validando /health..."
for i in $(seq 1 10); do
  if curl -fs http://localhost:8000/health > /dev/null; then
    echo ">> OK: API respondeu em /health (tentativa ${i})."
    echo ">> Deploy concluído com sucesso."
    exit 0
  fi
  sleep 2
done

echo "!! ERRO: API não respondeu em /health após o deploy." >&2
docker compose logs --tail=30 || true
exit 1
