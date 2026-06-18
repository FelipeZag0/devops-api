# Relatório Final — Seção 3a (Etapas das Fases 1 e 2)

Projeto **devops-api** — API REST Python 3.12 + FastAPI usada para demonstrar um
pipeline DevOps completo (CI → CD), com containerização, orquestração e
infraestrutura como código.

Repositório: https://github.com/FelipeZag0/devops-api

---

## Parte A — Relatório da Fase 1 (Configuração e Automação Inicial) — EAP 4.1.1.1

### A.1 Planejamento do projeto

Definiu-se uma **API REST genérica** como aplicação-alvo, por ser simples o
suficiente para focar nas práticas DevOps e completa o bastante para exercitar
build, testes, container e deploy. Decisões de ferramentas:

| Item | Escolha | Justificativa |
|---|---|---|
| Linguagem/Framework | Python 3.12 + FastAPI | produtividade, testabilidade e documentação automática (Swagger) |
| Testes | pytest + pytest-cov | padrão da comunidade Python, com cobertura |
| Lint | flake8 | análise estática simples e consolidada |
| CI/CD | GitHub Actions | integrado ao repositório, sem infra extra |
| IaC | AWS CloudFormation | nativo da AWS, declarativo |
| Cloud | AWS (us-east-1) | conta real disponível |
| Container | Docker | portabilidade entre ambientes |

### A.2 Aplicação

API FastAPI (`src/main.py`) com health check e um CRUD de itens em memória:

| Método | Rota | Descrição |
|---|---|---|
| GET | `/health` | Health check (`{"status":"ok"}`) |
| GET | `/items` | Lista os itens |
| POST | `/items` | Cria item (`name`, `description`) |
| GET | `/items/{id}` | Retorna item por ID |
| DELETE | `/items/{id}` | Remove item por ID |

Cobertura de testes: 7 casos em `tests/test_main.py` (pytest), cobrindo health e
o ciclo CRUD.

### A.3 Pipeline de Integração Contínua (CI)

Arquivo `.github/workflows/ci.yml`. Estratégia **GitHub Flow**: `main` protegida,
desenvolvimento em branches `feature/*` integradas via Pull Request.

- **Gatilhos:** `push` e `pull_request` na `main`
- **Runner:** `ubuntu-latest`
- **Steps:** checkout → setup-python 3.12 → `pip install` → flake8 → pytest --cov
  → docker build
- **Política de falha:** fail-fast — qualquer etapa que falhe interrompe o
  pipeline, bloqueia o merge (branch protection) e notifica o autor.

### A.4 Infraestrutura como Código (IaC)

Template CloudFormation (`infra/template.yaml`) que provisiona, em `us-east-1`:

- VPC (10.0.0.0/16) + subnet pública (10.0.1.0/24) com IP público automático
- Internet Gateway + Route Table
- Security Group liberando portas 22 (SSH) e 8000 (API)
- EC2 `t2.micro` Amazon Linux 2

Parâmetros configuráveis (`ProjectName`, `Environment`, `InstanceType`, `AmiId`,
CIDRs, `SshCidr`) e outputs (`InstanceId`, `InstancePublicIp`, `ApiUrl`, `VpcId`).
A aplicação não possui dependências de banco/fila/storage (estado em memória).

### A.5 Resultado da Fase 1

Repositório público criado, primeiro push realizado, pipeline CI executando em
verde e scripts IaC validados — base aprovada que serve de ponto de partida para
a Fase 2.

---

## Parte B — Relatório da Fase 2 (Entrega Contínua, Containers e Orquestração) — EAP 4.1.2.1

A Fase 2 estende o pipeline de **CI** para **CD** (entrega contínua), adiciona
orquestração com Docker Compose e automatiza o deploy na EC2.

### B.1 Estratégia e desenho do CD (EAP 2.1)

Documentado em `docs/cd-strategy.md`. Decisões principais:

- **Gatilho do CD:** `push` na `main` (após PR com CI verde). Em PRs roda só o CI.
  Implementa GitHub Flow com entrega contínua a cada merge.
- **Ambientes:** runner efêmero (CI) → Docker Hub (registry) → EC2 single-host (produção).
- **Estratégia de deploy:** *recreate* via SSH + Docker Compose (a API é stateless,
  sem migração de dados; downtime de poucos segundos é aceitável no escopo).
- **Versionamento de imagem (EAP 2.1.1.2):** cada imagem recebe duas tags —
  `latest` (ponteiro móvel usado pelo deploy) e `sha-<commit>` (imutável e
  rastreável, permite rollback). SemVer foi avaliado e descartado por adicionar
  etapa manual sem ganho no escopo acadêmico.

### B.2 Implementação do CD no GitHub Actions (EAP 2.2)

O `ci.yml` ganhou dois jobs novos, encadeados ao job `build` por `needs:`
(mantendo o fail-fast):

1. **`build-and-push`** (EAP 2.2.1) — após o CI, faz login no Docker Hub
   (`docker/login-action`) e publica a imagem com as tags `latest` e
   `sha-<commit>` (`docker/build-push-action`). Roda só em `push` na `main`.
   Credenciais via secrets `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`.
2. **`deploy`** (EAP 2.2.2) — após o push da imagem, copia `docker-compose.yml` e
   `scripts/deploy.sh` para a EC2 (`appleboy/scp-action`) e executa o deploy via
   SSH (`appleboy/ssh-action`). Credenciais via secrets `EC2_HOST` / `EC2_USER` /
   `EC2_SSH_KEY`.

Encadeamento: `build → build-and-push → deploy`. Se qualquer etapa anterior
falhar, as seguintes são puladas — nada é publicado nem implantado.

### B.3 Containerização (EAP 3.1)

`Dockerfile` revisado seguindo boas práticas:

- Base `python:3.12-slim`; camada de dependências separada (cache de build)
- Usuário **não-root** (`appuser`) — segurança
- `HEALTHCHECK` consultando `/health`
- `ENV PYTHONDONTWRITEBYTECODE/PYTHONUNBUFFERED`

Adicionado `.dockerignore` para reduzir o contexto de build (exclui `.git`,
`.venv`, `tests/`, `.github/`, `infra/`, `docs/`, etc.). Build e teste local
validados: imagem sobe como container `healthy`, `/health` e CRUD respondem
(evidência em `docs/evidencias-container-local.md`).

### B.4 Orquestração e scripts de deploy (EAP 3.2)

- **`docker-compose.yml`** — orquestra o serviço `api` de forma declarativa:
  imagem `${DOCKERHUB_USERNAME}/devops-api:latest`, porta 8000,
  `restart: unless-stopped` e `healthcheck`.
- **`scripts/deploy.sh`** — script idempotente (`set -euo pipefail`) que faz
  `docker compose pull` → `up -d --remove-orphans` → `image prune` → valida
  `/health`. Parametrizado por `DOCKERHUB_USERNAME`. É reutilizado pelo job de
  deploy do CD.
- Uso documentado na seção *Orquestração e Deploy* do `README.md`.

Validação local da orquestração: `docker compose up -d` deixa o serviço `healthy`
e a API acessível (evidência em `docs/evidencias-deploy-local.md`).

### B.5 Resultado da Fase 2

Pipeline expandido de CI para CD ponta a ponta (commit → CI → publicação da
imagem → deploy), aplicação containerizada com boas práticas e orquestrada via
Compose, com scripts de deploy automatizados e documentados. A execução real do
pipeline na EC2 e os prints correspondentes constituem a demonstração (EAP 2.3.1.1
e 4.2.2.1).

---

*Fontes deste relatório (artefatos no repositório):* `docs/cd-strategy.md`,
`.github/workflows/ci.yml`, `Dockerfile`, `.dockerignore`, `docker-compose.yml`,
`scripts/deploy.sh`, `infra/template.yaml`, `docs/evidencias-*.md`.
