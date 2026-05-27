# devops-api

API REST simples construída com Python + FastAPI, usada como base do projeto DevOps na Prática (PUCRS ADS).

## Tecnologias

- Python 3.12
- FastAPI
- pytest + pytest-cov
- flake8
- Docker
- AWS CloudFormation (IaC)
- GitHub Actions (CI)

## Endpoints

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/health` | Health check |
| GET | `/items` | Lista todos os itens |
| POST | `/items` | Cria um novo item |
| GET | `/items/{id}` | Retorna um item pelo ID |
| DELETE | `/items/{id}` | Remove um item pelo ID |

## Instalação e execução local

```bash
pip install -r requirements.txt
uvicorn src.main:app --reload
```

A documentação interativa estará disponível em `http://localhost:8000/docs`.

## Testes

```bash
pytest tests/ --cov=src --cov-report=term-missing
```

## Lint

```bash
flake8 src/ tests/ --max-line-length=100
```

## Docker

```bash
# Build
docker build -t devops-api .

# Run
docker run -p 8000:8000 devops-api
```

## Infraestrutura (AWS CloudFormation)

Pré-requisitos: AWS CLI configurado com credenciais válidas.

```bash
# Criar a stack
aws cloudformation create-stack \
  --stack-name devops-api \
  --template-body file://infra/template.yaml \
  --region us-east-1

# Acompanhar o status
aws cloudformation describe-stacks \
  --stack-name devops-api \
  --query "Stacks[0].StackStatus"

# Ver outputs (IP público, URL da API)
aws cloudformation describe-stacks \
  --stack-name devops-api \
  --query "Stacks[0].Outputs"

# Destruir a stack
aws cloudformation delete-stack --stack-name devops-api
```

Os recursos provisionados incluem: VPC, subnet pública, internet gateway, route table, security group e instância EC2 (t2.micro).
