# Evidência — Validação da orquestração / deploy (EAP 3.2.3.1)

Validação da orquestração com **Docker Compose** rodando localmente
(Docker Desktop / WSL2, Windows 11). Atende **C2** (orquestração), alimenta
**C1** (2.2.2.1) e **C3** (demonstração).

> **Escopo desta evidência (local):** valida a orquestração declarativa — compose
> sobe o serviço, aplica restart policy, healthcheck fica `healthy` e a API
> responde. O passo `docker compose pull` do `scripts/deploy.sh` (que baixa a
> imagem do Docker Hub) é exercitado de ponta a ponta **na EC2**, no pacote
> 2.3.1.1, após a imagem ser publicada pelo pipeline de CD. Aqui a imagem local
> foi marcada com o nome do compose para validar o `up` sem depender do registry.
>
> Substituir os blocos por **prints reais** ao montar o template/relatório.

## 1. Preparar a imagem para o compose

```bash
$ docker tag devops-api:local felipezag0/devops-api:latest
```

## 2. Subir via Docker Compose

```bash
$ DOCKERHUB_USERNAME=felipezag0 docker compose up -d
 Network devops-api_default  Created
 Container devops-api  Started
```

## 3. Estado do serviço

```bash
$ docker compose ps
NAME         IMAGE                          SERVICE   STATUS                    PORTS
devops-api   felipezag0/devops-api:latest   api       Up 37 seconds (healthy)   0.0.0.0:8000->8000/tcp

$ docker inspect --format='{{.State.Health.Status}}' devops-api
healthy
```

Container orquestrado pelo Compose, com `restart: unless-stopped` e estado
**healthy** reportado pelo healthcheck.

## 4. Endpoint acessível

```bash
$ curl http://localhost:8000/health
{"status":"ok"}
```

## 5. Encerramento

```bash
$ docker compose down
 Container devops-api  Removed
 Network devops-api_default  Removed
```

---

**Conclusão:** a orquestração com `docker-compose.yml` funciona — o serviço sobe,
fica healthy e serve a API na porta 8000. O `scripts/deploy.sh` reutiliza esse
mesmo `compose up -d` acrescido do `pull` da imagem do registry, validado na
execução real do pipeline (2.3.1.1).
