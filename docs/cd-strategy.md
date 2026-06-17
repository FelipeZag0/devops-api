# Estratégia e Desenho do CD — Fluxo CI → CD

> Pacote EAP **2.1.1.1** — Definir gatilhos, ambientes e estratégia de deploy.
> Artefato: descrição + diagrama do fluxo CI→CD (atende **C1 — clareza da expansão**).

Este documento especifica **quando** o pipeline de entrega contínua dispara,
**onde** a aplicação é entregue e **como** o deploy acontece. Ele consolida as
decisões que serão implementadas nos jobs do GitHub Actions (pacotes 2.2.x) e
serve de base para o fluxograma da Seção 3 (pacote 4.2.1.1).

---

## 1. Visão geral

O fluxo herdado da Fase 1 cobria apenas **CI** (integração contínua): a cada
`push`/`pull_request` na `main`, o GitHub Actions rodava lint → testes →
`docker build`. A Fase 2 **estende** esse fluxo para **CD** (entrega contínua):
após o CI passar, a imagem é publicada em um registry e implantada
automaticamente na infraestrutura provisionada na Fase 1 (EC2 em `us-east-1`).

```
  Desenvolvedor
       │  git push / abre PR
       ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         GitHub (repo devops-api)                     │
│                                                                     │
│  Evento: pull_request → main          Evento: push → main (merge)   │
│  ──────────────────────────           ──────────────────────────── │
│            CI                                    CI  →  CD            │
│                                                                     │
│   ┌──────────────────┐                  ┌──────────────────┐        │
│   │   job: build      │   needs:         │   job: build      │        │
│   │  (lint→test→      │ ───────────────► │  (lint→test→      │        │
│   │   docker build)   │                  │   docker build)   │        │
│   └──────────────────┘                  └────────┬─────────┘        │
│        (só valida,                               │ sucesso          │
│      NÃO faz deploy)                              ▼                  │
│                                          ┌──────────────────┐        │
│                                          │ job: build-push   │        │
│                                          │ login + build +   │ ──┐    │
│                                          │ push p/ registry  │   │    │
│                                          └────────┬─────────┘   │    │
│                                                   │ needs        │    │
│                                                   ▼              │    │
│                                          ┌──────────────────┐    │    │
│                                          │  job: deploy      │    │    │
│                                          │ SSH na EC2 →      │    │    │
│                                          │ pull + compose up │    │    │
│                                          └────────┬─────────┘    │    │
└───────────────────────────────────────────────────┼─────────────┼────┘
                                                     │             │
                  ┌──────────────────────────────────┘             │
                  ▼                                                 ▼
        ┌──────────────────┐                            ┌──────────────────┐
        │   EC2 (us-east-1) │  ◄── docker pull ───────── │  Docker Hub       │
        │  docker-compose   │                            │ felipezag0/       │
        │  API :8000 no ar  │                            │ devops-api:TAG    │
        └──────────────────┘                            └──────────────────┘
                  │
                  ▼  GET /health → 200
            Aplicação em produção
```

---

## 2. Gatilhos (quando o CD dispara)

| Evento | Branch | CI roda? | CD roda? | Racional |
|---|---|---|---|---|
| `pull_request` | → `main` | ✅ Sim | ❌ Não | Valida o código antes do merge; deploy não deve ocorrer em código não revisado/mesclado. |
| `push` (merge do PR) | `main` | ✅ Sim | ✅ Sim | A `main` é a fonte da verdade; todo merge aprovado é entregue automaticamente. |
| `push` direto | `main` | — | — | **Bloqueado** pela proteção de branch (exige PR + status check). |

**Decisão (2.1.1.1):** o CD dispara **apenas em `push` na `main`** (ou seja, após
o merge de um PR cujo CI ficou verde). Em PRs, executa-se somente o CI. Isso
implementa o **GitHub Flow** com entrega contínua: nada chega à `main` sem passar
pelo CI, e tudo que chega à `main` é implantado.

Condição técnica no workflow: o(s) job(s) de CD usarão
`if: github.event_name == 'push' && github.ref == 'refs/heads/main'` para não
rodar em pull requests, mantendo o mesmo arquivo de workflow para CI e CD.

> **Alternativa considerada e descartada:** disparo por *tag de release*
> (`v1.0.0`). Mais adequado a produtos com versionamento semântico e cadência de
> releases, mas adiciona uma etapa manual a cada entrega — desnecessário para o
> escopo single-host/acadêmico desta disciplina. Mantemos *trunk-based / deploy a
> cada merge na main*, que evidencia melhor a **continuidade** da entrega.

---

## 3. Ambientes

| Ambiente | Onde | Provisionamento | Uso |
|---|---|---|---|
| **CI (efêmero)** | runner `ubuntu-latest` (GitHub) | Descartável a cada execução | Lint, testes, build de validação. |
| **Registry** | Docker Hub `felipezag0/devops-api` | Conta + Access Token | Armazena as imagens versionadas publicadas pelo CD. |
| **Produção** | EC2 `t2.micro` Amazon Linux 2 (`us-east-1`) | CloudFormation (`infra/template.yaml`, Fase 1) | Host único onde a API roda em container via docker-compose. |

**Ambiente único (single-host):** por ser um projeto acadêmico, há **um único
ambiente de produção** (a EC2 da Fase 1). Não há staging. Essa limitação é
assumida conscientemente e será registrada na análise crítica (pacote 4.3.1.1)
como melhoria futura (separar `staging`/`prod`).

---

## 4. Estratégia de deploy

**Mecanismo:** SSH na EC2 + Docker Compose (pull da imagem publicada + `up -d`).

Sequência do job `deploy` (a ser implementado em 2.2.2.1):

1. Job `build-push` publica a imagem no Docker Hub com as tags definidas (ver
   pacote 2.1.1.2 — convenção de tagging).
2. Job `deploy` (`needs: build-push`) abre conexão SSH na EC2 usando secrets
   (`EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY`).
3. Na EC2, executa o script de deploy (`scripts/deploy.sh`, pacote 3.2.2.1):
   `docker compose pull` → `docker compose up -d` → remove imagens órfãs.
4. Validação pós-deploy: `curl http://localhost:8000/health` deve retornar `200`.

**Tipo de estratégia:** *recreate* (substituição direta do container). O
docker-compose para o container antigo e sobe o novo a partir da imagem
atualizada. Aceitável aqui porque:
- a API é *stateless* (estado em memória, sem banco) — não há migração de dados;
- a janela de indisponibilidade é de poucos segundos em um host único;
- não há requisito de zero-downtime no escopo da disciplina.

> Estratégias mais avançadas (blue-green, rolling, canary) exigem múltiplas
> instâncias/orquestrador (ECS, Kubernetes) e ficam fora do escopo single-host.
> Registradas como melhoria futura em 4.3.1.1.

**Encadeamento e fail-fast (2.2.2.2):** `build → build-push → deploy` ligados por
`needs:`. Se lint, teste ou build falharem, **nada é publicado nem implantado**;
se o push falhar, o deploy não ocorre. Mantém a política fail-fast da Fase 1.

---

## 5. Resumo das decisões (entrada para 2.1.1.2 e 2.2.x)

| Dimensão | Decisão |
|---|---|
| Gatilho do CD | `push` na `main` (após PR com CI verde) |
| Gatilho do CI | `push` e `pull_request` na `main` |
| Registry | Docker Hub — `felipezag0/devops-api` |
| Ambiente alvo | EC2 `t2.micro` Amazon Linux 2, `us-east-1` (host único) |
| Mecanismo de deploy | SSH + `docker compose pull && up -d` |
| Estratégia de deploy | Recreate (app stateless) |
| Encadeamento | `build` → `build-push` → `deploy` via `needs:` (fail-fast) |
| Convenção de tag | `latest` + `sha-<commit-curto>` (ver seção 6) |

---

## 6. Convenção de versionamento da imagem (EAP 2.1.1.2)

Toda imagem publicada no Docker Hub (`felipezag0/devops-api`) recebe **duas tags
simultâneas** a cada entrega:

| Tag | Exemplo | Como é gerada | Para que serve |
|---|---|---|---|
| `sha-<commit-curto>` | `sha-6ff58ea` | 7 primeiros caracteres de `${{ github.sha }}` | **Imutável e rastreável**: identifica exatamente o commit que originou a imagem. Permite rollback para uma versão específica. |
| `latest` | `latest` | Fixa, sobrescrita a cada push na `main` | **Ponteiro móvel**: sempre aponta para a última imagem entregue. É a tag que o deploy na EC2 puxa por padrão. |

**Exemplo de referência completa da imagem:**

```
felipezag0/devops-api:sha-6ff58ea     # versão exata do commit 6ff58ea
felipezag0/devops-api:latest          # mesma imagem, como "última versão"
```

**Por que `latest` + SHA (e não SemVer `v1.2.3`):**

- O **SHA** dá rastreabilidade total e imutável sem exigir gerência manual de
  versões — cada build mapeia 1:1 com um commit da `main`.
- O **`latest`** simplifica o deploy: o `docker-compose.yml` referencia
  `:latest` e o script só precisa de `docker compose pull` para obter a versão
  nova, sem editar arquivos a cada release.
- **SemVer** (`v1.0.0`) seria mais adequado a um produto com releases versionados
  e changelog; aqui adicionaria etapa manual de *tag/release* a cada entrega,
  sem ganho real no escopo single-host/acadêmico. Fica registrado como melhoria
  futura (pacote 4.3.1.1).

**Como será implementado (entrada para 2.2.1.1):** o job `build-push` usa
`docker/metadata-action` ou define as tags manualmente a partir de
`${{ github.sha }}`, publicando ambas no mesmo `docker push`:

```yaml
tags: |
  felipezag0/devops-api:latest
  felipezag0/devops-api:sha-${{ github.sha }}
```

> Observação: no workflow o SHA completo (`github.sha`) pode ser usado direto na
> tag; a forma curta `sha-6ff58ea` é a representação humana usada nesta
> documentação e nos prints da demonstração.

---

*Próximo pacote:* **2.2.1.1** — implementar o job `build-push` no GitHub Actions
aplicando esta convenção de tags e publicando no Docker Hub.
