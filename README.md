# ai_metricas

Empacotamento do **Umami** (métricas dos sites, sem cookie) e do **Postgres** dele para o fluxo de release do
[`vps_rt_infra`](https://github.com/RangelTech/vps_rt_infra). Este repositório não tem código de aplicação: só fixa por
digest as imagens oficiais (`images.env`), gera os artefatos e os manifestos. O deploy (stack `umami`, DNS
`metricas.rangeltech.net`, segredos gerados na própria VPS) é inteiramente do `vps_rt_infra`.

Fluxo: workflow **Release** (informe a versão) → `release-intake` do `vps_rt_infra` grava os locks `umami` e `umami-db`
→ workflow **Deploy** (primeiro `umami-db`, depois `umami`).

Sem segredo neste repositório. A senha do administrador vive no cofre do dono; aqui só existe o hash dela.
