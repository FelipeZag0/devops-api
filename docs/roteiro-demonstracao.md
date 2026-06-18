# Roteiro da demonstração funcional (EAP 4.2.2.1 — Seção 3b)

Roteiro para demonstrar o fluxo DevOps completo funcionando — do commit até a
aplicação no ar na EC2 — com evidências para C3.

> **Estado:** roteiro pronto. Os **prints/vídeo** finais são capturados ao
> executar o pipeline real (depende da EC2 ativa + secrets SSH — pacote 2.3.1.1).
> As evidências locais já existentes (`docs/evidencias-container-local.md`,
> `docs/evidencias-deploy-local.md`) complementam a demonstração.

## Pré-requisitos da demonstração

- [ ] EC2 ativa (stack CloudFormation) com Docker + plugin compose instalados
- [ ] `KeyName` no template / par de chaves SSH disponível
- [ ] Secrets no repo: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `EC2_HOST`,
      `EC2_USER` (`ec2-user`), `EC2_SSH_KEY`
- [ ] Branch `feature/fase2-cd` pronta para merge na `main`

## Roteiro passo a passo (capturar print em cada etapa)

### 1. Ponto de partida — aplicação local
- `docker compose up -d` e `curl http://localhost:8000/health` → `{"status":"ok"}`
  *(print 1 — app rodando localmente)*

### 2. Disparar o fluxo — commit/PR
- Abrir Pull Request `feature/fase2-cd` → `main`
- Mostrar o CI rodando automaticamente no PR (lint → test → build)
  *(print 2 — checks do PR em andamento/verdes)*

### 3. Integração Contínua (CI)
- Na aba *Actions*, abrir o run do job **build**: etapas verdes (flake8, pytest, docker build)
  *(print 3 — job build verde, com saída dos testes)*

### 4. Merge → Entrega Contínua (CD)
- Fazer o merge do PR (com CI verde) → dispara o fluxo de CD
- Job **build-and-push**: login + push da imagem
  *(print 4 — job build-and-push verde)*
- Mostrar a imagem publicada no **Docker Hub** com as tags `latest` e `sha-<commit>`
  *(print 5 — repositório no Docker Hub com as tags)*

### 5. Deploy automatizado na EC2
- Job **deploy**: log do SCP + SSH executando `deploy.sh`
  (`compose pull` → `up -d` → `OK: API respondeu em /health`)
  *(print 6 — log do job deploy verde com a saída do script)*

### 6. Aplicação no ar (prova final)
- `curl http://<EC2_PUBLIC_IP>:8000/health` → `{"status":"ok"}`
- `curl -X POST http://<EC2_PUBLIC_IP>:8000/items -d '{"name":"demo","description":"deploy via CD"}'`
- `curl http://<EC2_PUBLIC_IP>:8000/items` → item criado
  *(print 7 — API respondendo no IP público da EC2)*

### 7. (Opcional) Prova de continuidade
- Alterar algo simples (ex.: mensagem), commit/PR/merge → mostrar nova imagem
  `sha-<novo-commit>` publicada e o deploy atualizando o container automaticamente
  *(print 8 — segundo ciclo, evidenciando a "continuidade" da entrega)*

## Checklist de evidências para o template (Seção 3b)

| # | Evidência | Origem |
|---|---|---|
| 1 | App local rodando (`/health`) | local — já validado |
| 2 | CI no PR | GitHub Actions |
| 3 | Job build verde (testes) | GitHub Actions |
| 4 | Job build-and-push verde | GitHub Actions |
| 5 | Imagem no Docker Hub (tags) | Docker Hub |
| 6 | Job deploy verde (log do script) | GitHub Actions |
| 7 | API no ar na EC2 (`/health` + CRUD) | EC2 |
| 8 | Fluxograma | `docs/fluxograma-cicd.md` |
