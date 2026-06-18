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
#   - Docker + Compose (plugin v2 "docker compose" OU binário v1 "docker-compose")
#   - docker-compose.yml presente no diretório atual
# Variáveis:
#   - DOCKERHUB_USERNAME : usuário do Docker Hub dono da imagem (default: felipezag0)
#   - IMAGE_TAG          : tag da imagem a implantar (default: latest; ex.: sha-<commit>)
# ============================================================================

set -euo pipefail   # aborta em erro, variável indefinida ou falha em pipe

# Usuário do Docker Hub e tag (usados pelo compose para montar o nome da imagem).
export DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-felipezag0}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
IMAGE="${DOCKERHUB_USERNAME}/devops-api:${IMAGE_TAG}"

# Compatibilidade compose v2 (plugin "docker compose") x v1 (binário "docker-compose").
# Amazon Linux 2, por exemplo, pode ter apenas o v1.
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "!! ERRO: Docker Compose não encontrado (nem 'docker compose' nem 'docker-compose')." >&2
  exit 1
fi

echo ">> Deploy da devops-api iniciado ($(date '+%Y-%m-%d %H:%M:%S'))"
echo ">> Imagem alvo: ${IMAGE}  (compose: ${DC})"

# 1. Puxa a versão alvo da imagem do registry.
echo ">> [1/4] Baixando a imagem (${IMAGE_TAG})..."
$DC pull

# 2. (Re)cria o container com a nova imagem. --remove-orphans limpa serviços
#    antigos; o compose recria apenas o que mudou.
echo ">> [2/4] Subindo o container..."
$DC up -d --remove-orphans

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
$DC logs --tail=30 || true
exit 1
