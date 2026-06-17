# Fluxograma CI/CD ponta a ponta (EAP 4.2.1.1 — Seção 3b)

Representa o fluxo completo do projeto **devops-api**: do commit do desenvolvedor
até a aplicação em execução na EC2. **Item obrigatório para a nota máxima de C3.**

> **Como gerar a imagem para o template:** o diagrama abaixo está em
> [Mermaid](https://mermaid.js.org). Para exportar como PNG/SVG:
> - cole o bloco `mermaid` em https://mermaid.live e clique em *Download* (PNG/SVG), ou
> - no VS Code use a extensão *Markdown Preview Mermaid Support* e exporte, ou
> - `npx @mermaid-js/mermaid-cli -i docs/fluxograma-cicd.md -o fluxograma.png`.
> Inserir a imagem resultante na Seção 3b do template.

## Fluxograma principal (commit → app no ar)

```mermaid
flowchart TD
    A([Desenvolvedor: git push / abre PR]) --> B{Evento no GitHub}

    B -->|pull_request → main| C[CI: job build]
    B -->|push → main após merge| C

    subgraph CI [Integração Contínua - runner ubuntu-latest]
        C --> C1[Checkout + setup-python 3.12]
        C1 --> C2[pip install]
        C2 --> C3[Lint: flake8]
        C3 --> C4[Testes: pytest --cov]
        C4 --> C5[docker build]
    end

    C5 --> D{Sucesso do CI?}
    D -->|Não| DF([Falha: merge bloqueado + autor notificado]):::fail
    D -->|Sim, e foi PR| DM([Pronto para merge - sem deploy]):::ok
    D -->|Sim, e foi push na main| E[CD: job build-and-push]

    subgraph CD [Entrega Contínua]
        E --> E1[Login no Docker Hub]
        E1 --> E2[Build & push da imagem<br/>tags: latest + sha-commit]
        E2 --> F[(Docker Hub<br/>felipezag0/devops-api)]
        F --> G[CD: job deploy]
        G --> G1[SCP: copia compose + deploy.sh p/ EC2]
        G1 --> G2[SSH: executa scripts/deploy.sh]
    end

    subgraph EC2 [Infraestrutura - EC2 us-east-1]
        G2 --> H1[docker compose pull]
        H1 --> H2[docker compose up -d --remove-orphans]
        H2 --> H3[image prune]
        H3 --> H4{curl /health == 200?}
    end

    H4 -->|Sim| I([API no ar - container healthy<br/>http://EC2:8000]):::ok
    H4 -->|Não| HF([Deploy falha - logs do container]):::fail

    classDef ok fill:#d4edda,stroke:#28a745,color:#155724;
    classDef fail fill:#f8d7da,stroke:#dc3545,color:#721c24;
```

## Encadeamento dos jobs (needs / fail-fast)

```mermaid
flowchart LR
    J1[build<br/>lint+test+docker build] -->|needs| J2[build-and-push<br/>publica imagem]
    J2 -->|needs| J3[deploy<br/>SSH na EC2]
    J1 -. falha pula os seguintes .-> X([nada publicado<br/>nada implantado]):::fail
    classDef fail fill:#f8d7da,stroke:#dc3545,color:#721c24;
```

## Legenda das etapas

| Fase | Onde | O que acontece |
|---|---|---|
| Commit | Local / GitHub | `git push` ou abertura de PR para `main` |
| CI | Runner GitHub | lint (flake8) → testes (pytest) → docker build |
| CD - build-push | Runner GitHub | login + build + push da imagem (latest + sha) |
| CD - deploy | Runner → EC2 | SCP do compose/script + SSH executando `deploy.sh` |
| Infra | EC2 us-east-1 | `compose pull` + `up -d` + prune + valida `/health` |
| App | EC2:8000 | API FastAPI em execução, container healthy |
