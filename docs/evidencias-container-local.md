# Evidência — Build e teste local do container (EAP 3.1.2.1)

Validação da imagem Docker rodando localmente (Docker Desktop / WSL2, Windows 11).
Atende **C2** (containerização) e habilita **C1** (a mesma imagem é publicada e
implantada pelo pipeline de CD).

> Substituir os blocos abaixo por **prints reais** do terminal ao montar o
> template/relatório (a demonstração visual conta para C2/C3).

## 1. Build da imagem

```bash
$ docker build -t devops-api:local .
...
#11 [6/6] RUN useradd --create-home appuser
#11 DONE 0.3s
#12 naming to docker.io/library/devops-api:local done
#12 DONE 1.5s
```

Build concluído com sucesso (imagem `devops-api:local`).

## 2. Execução do container

```bash
$ docker run -d --name devops-api-test -p 8000:8000 devops-api:local
e6af2ef1ff30...

$ docker ps --filter name=devops-api-test
devops-api:local   Up 13 seconds (healthy)   0.0.0.0:8000->8000/tcp
```

Container ativo e marcado **(healthy)** pelo HEALTHCHECK definido no Dockerfile.

## 3. Teste do endpoint /health

```bash
$ curl http://localhost:8000/health
{"status":"ok"}
```

## 4. Teste funcional do CRUD (prova de que a API está operando)

```bash
$ curl -X POST http://localhost:8000/items \
    -H "Content-Type: application/json" \
    -d '{"name":"teste","description":"validacao container"}'
{"id":1,"name":"teste","description":"validacao container"}

$ curl http://localhost:8000/items
[{"id":1,"name":"teste","description":"validacao container"}]
```

## 5. Limpeza

```bash
$ docker rm -f devops-api-test
```

---

**Conclusão:** a imagem builda, sobe como usuário não-root, passa no healthcheck e
serve a API corretamente (health + CRUD) na porta 8000 — pronta para ser publicada
no registry e implantada pelo pipeline de CD.
