# Pool 3 — matriz mecânica de dependências

Fonte de verdade para execução: `scripts/campaign/event_campaign_dependencies.gd`, IDs dos Resources e tags explícitas. Nomes exibidos e menções narrativas não classificam dependência. A validação cruzada é `EventCampaignDependencies.catalog_errors()`; após adicionar ou mudar um Resource, executar `scripts/tests/ppp_campaign_pool3_test.gd` e a auditoria do Pool 0.

| ID | Tipo e dependência mecânica | Curta / média | Completa |
| --- | --- | --- | --- |
| `ev_00001` | Direto, desfecho `khainokata`; condição de Informação no outcome | Fora do sorteio normal, mesmo com Khainokata ativo | Elegível segundo demais regras |
| `ev_00002` | Direto, `orchestra`; condição de Informação e concessão fixa `in_00019` | Fora do sorteio normal; se forçado, ID inativo não é substituído | Elegível segundo demais regras |
| `ev_00003` | Direto, `homens_de_preto`; condição por Informação e Encontro dinâmico via `start_crazy_old_man_combat_scaled_to_group` | Fora do sorteio normal | Elegível segundo demais regras |
| `ev_00004` | Direto, `controle_da_mente`; condição por Informação e Encontro dinâmico via `start_dancing_zombie_horde_by_district` | Fora do sorteio normal | Elegível segundo demais regras |
| `ev_00017` | Indireto; outcome de aceite concede Informação, recusa não | Fora do sorteio normal; se forçado, concessão só de parte ativa e inédita | Elegível; mesma validação da concessão |
| `ev_00044` | Indireto; outcome de vitória concede Informação, derrota esquece a última | Fora do sorteio normal; se forçado, concessão só de parte ativa e inédita | Elegível; mesma validação da concessão |
| `ev_00049` | Evento misto; somente outcome `random_information` concede Informação | Evento elegível; esse desejo ausente e rejeitado se acionado diretamente | Evento e desejo elegíveis; concessão limitada a parte ativa e inédita |
| `enc_00011` | A Experiência; associação a `orchestra` afeta apenas recrutamento, **não** a entrada do Encontro | Com Orchestra ativo: pistas `in_00017`/`in_00018` dão 50%/75%. Sem Orchestra: 2/4 Informações globais dão 50% fixos | Pistas Orchestra dão 50%/75%; sem pistas, não há oferta |

O filtro de Eventos roda antes dos sorteios normais do mapa, blocos livres/por valência e das entradas secundárias (Saci, filhos e encadeamentos). Um pool de valência vazio continua vazio: não reinserir Evento excluído como substituto. Pesos dos candidatos restantes permanecem os dos Resources. Encontros só associados por tema (inclusive Zumbis e Homens de Preto) não são bloqueados por falta de uma série; uma eventual recompensa de Informação incompatível é que é recusada. Se um outcome tem efeito independente além da Informação inválida ou esgotada, esse efeito prossegue e a caixa informa por que a Informação não foi concedida.

Regressões da etapa: `ppp_campaign_pool3_test.gd`, `ppp_a_experiencia_recruitment_test.gd`, `ppp_campaign_secondary_event_filter_test.gd`, `ppp_campaign_event_tags_test.gd`, `ppp_genie_event_test.gd` e `ppp_campaign_pool2_test.gd`. O painel futuro de debug deve marcar explicitamente quando força um Evento fora do pool; forçar não contorna a validação central de Informação.
