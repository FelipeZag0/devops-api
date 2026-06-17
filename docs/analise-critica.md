# Análise crítica e melhorias futuras (EAP 4.3.1.1 — Seção 3c)

Avaliação crítica do que foi implementado no projeto **devops-api** ao longo das
Fases 1 e 2, com as limitações conscientemente assumidas e um plano de evolução.

---

## 1. Resultados alcançados

O projeto entregou um fluxo DevOps **ponta a ponta automatizado**, partindo de um
commit e chegando à aplicação em execução, sem intervenção manual:

- **Integração Contínua:** todo push/PR é validado por lint (flake8), testes
  (pytest com cobertura) e build da imagem, com política *fail-fast* e merge
  bloqueado por status check — garante que código quebrado não chega à `main`.
- **Entrega Contínua:** a cada merge na `main`, a imagem é versionada
  (`latest` + `sha-<commit>`), publicada no Docker Hub e implantada
  automaticamente na EC2 via SSH + Docker Compose, com validação de `/health`
  pós-deploy.
- **Containerização com boas práticas:** imagem enxuta, usuário não-root,
  healthcheck e `.dockerignore`.
- **Orquestração declarativa:** `docker-compose.yml` com restart policy e
  healthcheck, reutilizado pelo script de deploy idempotente.
- **Rastreabilidade:** a tag `sha-<commit>` liga cada imagem ao commit exato que
  a originou, viabilizando rollback.

O resultado evidencia os três pilares cobrados: expansão CI→CD (C1),
containerização e orquestração (C2) e documentação/demonstração do fluxo (C3).

## 2. Limitações (assumidas conscientemente no escopo acadêmico)

| # | Limitação | Impacto | Por que foi aceita |
|---|---|---|---|
| L1 | **Ambiente único** (sem staging/prod separados) | Mudanças vão direto para o único host; sem ambiente de homologação | Escopo single-host da disciplina; conta AWS individual |
| L2 | **Sem observabilidade** (logging centralizado, métricas, alertas) | Diagnóstico depende de `docker logs` manual na EC2 | Fora do escopo central de CI/CD desta fase |
| L3 | **Deploy *recreate*** (downtime de segundos) | Breve indisponibilidade a cada deploy | API stateless; sem requisito de zero-downtime |
| L4 | **Estado em memória** (sem banco) | Dados perdidos ao recriar o container | Aplicação é demonstrativa do pipeline, não do domínio |
| L5 | **Host único = SPOF** (sem alta disponibilidade) | Queda da EC2 derruba a aplicação | Custo/complexidade fora do escopo |
| L6 | **Segurança parcial** (token exposto a rotacionar; `SshCidr` 0.0.0.0/0 padrão; sem scanning de imagem) | Superfície de ataque maior | Aceitável em ambiente de estudo, mas é a maior dívida |
| L7 | **`latest` como tag de deploy** | Menos determinístico que fixar o SHA | Simplicidade; mitigado pela tag `sha-<commit>` coexistir |

## 3. Melhorias futuras propostas

Priorizadas por relação valor/esforço:

### Curto prazo (baixo esforço, alto valor)
- **Segurança imediata:** rotacionar o `DOCKERHUB_TOKEN`, restringir `SshCidr`
  ao IP do operador e adicionar **scanning de imagem** (Trivy / `docker scout`)
  como step do CI.
- **Deploy determinístico:** o job de deploy passar a referenciar a tag
  `sha-<commit>` (em vez de `latest`), garantindo que o host roda exatamente o
  artefato testado.
- **Healthcheck no CI pós-build:** subir o container no runner e validar `/health`
  antes de publicar (test de fumaça da imagem).

### Médio prazo
- **Ambiente de staging:** separar `staging`/`prod` (parâmetro `Environment` já
  existe no template), promovendo a imagem entre ambientes.
- **Observabilidade:** centralizar logs (CloudWatch Logs) e expor métricas
  (Prometheus + Grafana ou CloudWatch), com alarme sobre o `/health`.
- **Mais testes:** testes de integração e contrato da API; elevar/garantir
  cobertura mínima como *gate*.

### Longo prazo
- **Alta disponibilidade e zero-downtime:** migrar de single-host para um
  orquestrador (ECS/Fargate ou Kubernetes) com estratégia *rolling*/*blue-green*.
- **Persistência real:** introduzir banco gerenciado (RDS) e versionar migrações.
- **Versionamento semântico + releases:** adotar SemVer com changelog quando o
  projeto evoluir para um produto com cadência de releases.

## 4. Conclusão

O pipeline atinge o objetivo central da disciplina: **automatizar a jornada do
commit à produção** com qualidade (testes/lint), rastreabilidade (tags por
commit) e repetibilidade (IaC + container + scripts). As limitações são, em sua
maioria, decisões de escopo conscientes e documentadas — e o desenho modular
(parâmetros de ambiente no template, jobs encadeados, scripts parametrizados)
deixa o caminho aberto para as evoluções propostas, com destaque para o
endurecimento de segurança e a observabilidade como próximos passos de maior
retorno.
