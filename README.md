# devops-api

API REST construída com Python 3.12 + FastAPI, usada como projeto prático da disciplina de DevOps (PUCRS ADS).

Repositório: https://github.com/FelipeZag0/devops-api

![CI](https://github.com/FelipeZag0/devops-api/actions/workflows/ci.yml/badge.svg)

---

## Tecnologias

| Camada | Ferramenta |
|---|---|
| Linguagem | Python 3.12 |
| Framework | FastAPI |
| Testes | pytest + pytest-cov |
| Lint | flake8 |
| Containerização | Docker |
| IaC | AWS CloudFormation |
| CI | GitHub Actions |

---

## Instalação local

**Pré-requisito:** Python 3.12+

```bash
# 1. Clonar o repositório
git clone https://github.com/FelipeZag0/devops-api.git
cd devops-api

# 2. Criar e ativar o ambiente virtual
python3 -m venv .venv
source .venv/bin/activate   # Linux/macOS
# .venv\Scripts\activate    # Windows

# 3. Instalar dependências
pip install -r requirements.txt
```

---

## Execução

```bash
uvicorn src.main:app --reload
```

A API estará disponível em `http://localhost:8000`.  
Documentação interativa (Swagger): `http://localhost:8000/docs`.

---

## Endpoints

| Método | Rota | Descrição |
|---|---|---|
| GET | `/health` | Health check |
| GET | `/items` | Lista todos os itens |
| POST | `/items` | Cria um novo item (`name`, `description`) |
| GET | `/items/{id}` | Retorna um item pelo ID |
| DELETE | `/items/{id}` | Remove um item pelo ID |

---

## Testes

```bash
pytest tests/ --cov=src --cov-report=term-missing
```

Resultado esperado: **7 testes passando, cobertura 100%**.

---

## Lint

```bash
flake8 src/ tests/ --max-line-length=100
```

---

## Docker

A aplicação é containerizada com um `Dockerfile` baseado em `python:3.12-slim`,
seguindo boas práticas: camada de dependências cacheável, usuário **não-root**,
`HEALTHCHECK` no endpoint `/health` e `.dockerignore` para reduzir o contexto de build.

```bash
# Build da imagem
docker build -t devops-api .

# Executar o container (mapeando a porta 8000 do host)
docker run -p 8000:8000 devops-api

# Verificar a aplicação
curl http://localhost:8000/health   # -> {"status":"ok"}
```

Para inspecionar o estado de saúde reportado pelo HEALTHCHECK:

```bash
docker ps                            # coluna STATUS mostra (healthy)
```

> Orquestração com Docker Compose e deploy automatizado: ver seção
> [Orquestração e Deploy](#orquestração-e-deploy).

---

## Orquestração e Deploy

A aplicação é orquestrada de forma declarativa com **Docker Compose** e implantada
por um script de deploy idempotente, usado tanto localmente quanto pelo pipeline
de CD (que o executa na EC2 via SSH).

### Orquestração local com Docker Compose

```bash
# Sobe a API em background a partir da imagem publicada no Docker Hub
DOCKERHUB_USERNAME=felipezag0 docker compose up -d

# Acompanhar logs
docker compose logs -f

# Derrubar
docker compose down
```

O serviço `api` (arquivo `docker-compose.yml`) expõe a porta `8000`, usa
`restart: unless-stopped` e tem `healthcheck` no endpoint `/health`.

### Deploy automatizado (`scripts/deploy.sh`)

O script `scripts/deploy.sh` puxa a última imagem (`:latest`) do registry e
(re)sobe o container via Compose, validando o `/health` ao final.

**Pré-requisitos no host alvo (EC2):**
- Docker + plugin `docker compose` instalados
- `docker-compose.yml` e `scripts/deploy.sh` presentes no diretório atual

**Variáveis:**

| Variável | Padrão | Descrição |
|---|---|---|
| `DOCKERHUB_USERNAME` | `felipezag0` | Usuário do Docker Hub dono da imagem |

**Execução manual:**

```bash
cd ~/devops-api
DOCKERHUB_USERNAME=felipezag0 ./scripts/deploy.sh
```

O script é executado **automaticamente pelo pipeline de CD** a cada push na
`main`: o job `deploy` copia o `docker-compose.yml` e o `scripts/deploy.sh` para
a EC2 e roda o script via SSH. Detalhes do fluxo em
[`docs/cd-strategy.md`](docs/cd-strategy.md).

---

## Infraestrutura (AWS CloudFormation)

O diretório `infra/` contém o template CloudFormation que provisiona toda a infraestrutura na AWS.

**Recursos provisionados:** VPC, subnet pública, internet gateway, route table, security group e instância EC2 (t2.micro, Amazon Linux 2). Ao subir, a instância instala Docker, clona o repositório e executa a API automaticamente.

### Pré-requisitos

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) instalado e configurado (`aws configure`)
- Credenciais com permissões: `ec2:*`, `cloudformation:*`, `vpc:*`
- Região: `us-east-1`

### Parâmetros configuráveis

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `ProjectName` | `devops-api` | Prefixo dos recursos |
| `Environment` | `dev` | Ambiente (`dev`, `staging`, `prod`) |
| `InstanceType` | `t2.micro` | Tipo da instância EC2 |
| `AmiId` | `ami-0c02fb55956c7d316` | AMI Amazon Linux 2 (us-east-1) |
| `VpcCidr` | `10.0.0.0/16` | CIDR da VPC |
| `SubnetCidr` | `10.0.1.0/24` | CIDR da subnet pública |
| `SshCidr` | `0.0.0.0/0` | CIDR permitido para SSH (restrinja em produção) |

### Comandos

```bash
# 1. Validar sintaxe do template
aws cloudformation validate-template \
  --template-body file://infra/template.yaml \
  --region us-east-1

# 2. Criar a stack
aws cloudformation create-stack \
  --stack-name devops-api \
  --template-body file://infra/template.yaml \
  --region us-east-1

# 3. Acompanhar o status
aws cloudformation describe-stacks \
  --stack-name devops-api \
  --query "Stacks[0].StackStatus"

# 4. Ver outputs (IP público, URL da API)
aws cloudformation describe-stacks \
  --stack-name devops-api \
  --query "Stacks[0].Outputs"

# 5. Destruir a stack
aws cloudformation delete-stack --stack-name devops-api
```

Para sobrescrever parâmetros na criação:

```bash
aws cloudformation create-stack \
  --stack-name devops-api \
  --template-body file://infra/template.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=Environment,ParameterValue=prod \
    ParameterKey=InstanceType,ParameterValue=t3.small \
    ParameterKey=SshCidr,ParameterValue=SEU_IP/32
```
