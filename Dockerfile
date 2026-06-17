# ── Imagem base ───────────────────────────────────────────────────────────
# python:3.12-slim = Python 3.12 oficial em Debian enxuto (imagem pequena,
# sem ferramentas de build desnecessárias). Bom equilíbrio tamanho x praticidade.
FROM python:3.12-slim

# ── Variáveis de ambiente do Python ──────────────────────────────────────
# PYTHONDONTWRITEBYTECODE: não gera arquivos .pyc (imagem mais limpa).
# PYTHONUNBUFFERED: logs saem na hora (importante p/ ver logs no Docker/CI).
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Diretório de trabalho dentro do container.
WORKDIR /app

# ── Dependências (camada cacheável) ──────────────────────────────────────
# Copiar só o requirements antes do código aproveita o cache do Docker:
# enquanto as dependências não mudam, esta camada não é reconstruída.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ── Código da aplicação ──────────────────────────────────────────────────
COPY src/ ./src/

# ── Usuário não-root (boa prática de segurança) ──────────────────────────
# Rodar como usuário sem privilégios reduz o impacto de uma eventual falha.
RUN useradd --create-home appuser
USER appuser

# Porta em que a API escuta (documental; publicação real é via -p / compose).
EXPOSE 8000

# ── Health check ─────────────────────────────────────────────────────────
# O Docker passa a marcar o container como healthy/unhealthy consultando /health.
# Útil para o compose e para o deploy saberem se a aplicação subiu de fato.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

# ── Comando de inicialização ─────────────────────────────────────────────
# Sobe o servidor uvicorn servindo a app FastAPI em 0.0.0.0:8000.
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
