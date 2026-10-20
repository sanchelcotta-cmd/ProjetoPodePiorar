# Roteiro de retorno — integração da campanha 0.5

Complemento operacional de `PPP_PROXIMA_LEVA_CAMPANHA_0_5.md`. Este arquivo aponta **onde voltar** ao passar de um pool para outro. Marcadores: **FEITO** = código/teste já aplicado; **PARCIAL** = há base existente, falta integração; **PENDENTE** = ainda não executado. A matriz verificável do Pool 0 está em `PPP_POOL0_MATRIZ_EVENTOS.md`.

## Registro de agora

| Chave de busca | Estado | Local | O que falta ligar |
| --- | --- | --- | --- |
| `somente_campanha_completa` | **FEITO como dado e filtro** | Seis Resources → `EventData.tags`; `EventCampaignEligibility`; gerador, Saci, encadeamentos, filhos gerados e executor | Modo já chega da tela inicial; testar campanhas avançadas com standby. |
| `contem_outcomes_restritos_por_modo` | **FEITO como dado** | `resources/events/random_events/49-genio_da_lampada.tres` → `EventData.tags` | Marcador de inspeção; **não** exclui o Gênio. |
| `random_information` + `somente_campanha_completa` | **FEITO como dado e filtro** | `49-genio_da_lampada.tres` → `Outcome_information.tags`; `block_activation_popup.gd`; `event_executor.gd` | UI oculta e executor rejeita em curta/média; modo já chega da tela inicial. |
| `ppp_campaign_event_tags_test.gd` | **FEITO** | `scripts/tests/ppp_campaign_event_tags_test.gd` | Reexecutar após editar Resources ou renomear tags; valida presença e escopo das tags, **não** o comportamento por modo. |
| `ppp_campaign_secondary_event_filter_test.gd` | **FEITO** | `scripts/tests/ppp_campaign_secondary_event_filter_test.gd` | Testa curta/média por estado fixado no teste: mapa, Saci, filho gerado, encadeamento e Gênio. |
| `IDENTIDADE_CAMPANHA` / `VERSAO_ESTADO` | **FEITO no modelo** | `campaign_state.gd`; `ppp_campaign_identity_test.gd` | UUID v4, esquema 1, modo/desfechos definidos na seleção e estado terminal existem. Vitória/derrota ficam para o Pool 2 e persistência para o Pool 4. |

As tags de assunto (`orchestra`, `homens_de_preto`, `controle_da_mente` etc.) permanecem para outros usos; **não** devem ser interpretadas como dependência mecânica nem como exclusividade de campanha. IDs estáveis de Evento/outcome e tags explícitas são a fonte para a política futura; nomes exibidos e narrativa nunca são condição de código.

## Mapa de integração por pool

| Pool / palavras-chave de pendência | Arquivos de retorno | Verificação necessária antes de fechar |
| --- | --- | --- |
| **0 · `AUDITAR_ORIGENS_INFO`, `MATRIZ_EVENTOS`, `REFERENCIAS_ORFAS`** | `PPP_POOL0_MATRIZ_EVENTOS.md`; `scripts/tests/ppp_pool0_resource_audit.gd`; `campaign_state.gd`, `gerencia_jogo.gd`, gerador, managers, UI e Resources | **Auditoria registrada:** 85 Eventos, 20 Informações, 36 Encontros, rotas, referências e riscos. Reexecutar inventário ao acrescentar Resources. Cenários de esgotamento avançado ficam para aceite do Pool 3. |
| **1 · `MODO_CAMPANHA`, `DESFECHOS_ATIVOS`, `META_INFO`, `ELEGIBILIDADE_INFO_ID`** | `scripts/campaign/{campaign_state,gerencia_jogo,information_campaign_eligibility}.gd`; `playable_selection_screen.gd`; `playable_selection.tscn`; `ppp_campaign_{modes,information_eligibility}_test.gd` | **Itens 1–3 feitos:** identidade, versão, status, botões de modo/desfechos, sorteio uma vez, validação 1/2/4, meta 5/10/20 e consulta por ID/tag/tipo. Resumo preto mostra resultado real antes do primeiro mapa; voltar não refaz o sorteio. Consumidores ainda devem chamar a consulta no Pool 2. |
| **2 · `CONCEDER_INFO`, `POOL_ATIVO`, `VITORIA`, `DERROTA`** | `campaign_state.gd` (`record_information_obtained`, `forget_last_information`, `filter_uncollected_information`); `gerencia_jogo.gd` (`record_information_obtained`, `prepare_map`); `block_manager.gd` (`confirm_information`); `event_executor.gd` (`_information_candidates`, `_apply_effect`); `round_manager.gd`; `combat_manager.gd` | Uma concessão central para hex, Evento, Encontro e depuração; rejeitar IDs repetidos/inativos, preservar 1 hex fixo + até 1 livre e a transição por Informação. Vitória após 5/10/20 válidas, sem disparo duplo; derrota usa morte real. |
| **3 · `FILTRAR_TAG_EVENTO`, `FILTRAR_TAG_OUTCOME`, `CADEIA_EVENTOS`, `EXPERIENCIA`** | `event_campaign_eligibility.gd`; `ppp_map_generator.gd`; `event_executor.gd` (`_event_by_id`, `_select_outcome`, `_information_candidates`); `gnomes_3_manager.gd`; `block_activation_popup.gd`; `combat_manager.gd` | **Filtro de tags já aplicado e testado.** Falta integrar desfechos ativos ao sorteio/concessão de Informação, regra alternativa de A Experiência e casos de pool vazio ao longo de campanha real. |
| **4 · `SAVE_LOAD`, `AUTOSAVE`, `VERSAO_ESTADO`** | `campaign_state.gd`, `gerencia_jogo.gd`, mapa/hexes, subsistemas de entidades/itens/combate; futuro serviço de persistência | Auditar primeiro se há persistência operacional fora desses caminhos. Serializar o resultado do sorteio de modo/desfechos e das decisões, não rerrolar ao carregar. Três slots por campanha + recuperação oculta; nenhum salvamento parcial anunciado como concluído. |
| **5 · `MENU`, `CONFIRMAR_SAIDA`, `FIM_DIA`** | telas inicial/pausa, `round_manager.gd`, serviço real de save/load do Pool 4 | Ligar navegação e confirmações a operações reais; convite de save só na transição Noite → Dia. |
| **6 · `DEBUG_FORCADO`, `MOTIVO_INELEGIVEL`** | futuro painel de depuração; operações centrais dos Pools 1–3 | Forçar conteúdo apenas com indicação explícita de estado impossível; nunca contornar validação de Informação sem aviso. |
| **7 · `ACEITE_CRUZADO`, `REGRESSAO_TAGS`** | testes dos Pools 0–6, `scripts/tests/ppp_campaign_event_tags_test.gd`, `PPP_PROXIMA_LEVA_CAMPANHA_0_5.md` | Executar matriz curta/média/completa, checar que 01–04/17/44 não reaparecem por caminho secundário e que o Gênio mantém os demais desejos. Registrar resultados, não só existência dos testes. |

## Pontos que exigem duas travas

1. **Evento inteiro — feito:** gerador, linha do Saci, filhos gerados, pré-sorteio de encadeamento e resolução consultam `EventCampaignEligibility`. `CampaignState.campaign_mode` usa o modo escolhido na tela inicial; Completa é o padrão das chamadas antigas.
2. **Escolha do Gênio — feito:** `_show_genie_wishes` esconde `random_information` em curta/média e `_select_outcome` rejeita chamada direta. Os demais desejos seguem disponíveis.
3. **Informação concedida:** `_information_candidates` deve usar somente desfechos ativos ainda não obtidos; `CampaignState.record_information_obtained` precisa ser a validação final. Só filtrar candidatos não impede IDs fixos ou chamadas diretas.

## Estado de validação

Em 19/10/2026, passaram `ppp_pool0_resource_audit.gd`, `ppp_campaign_event_tags_test.gd`, `ppp_campaign_secondary_event_filter_test.gd` e as regressões existentes `ppp_map_generator_test.gd` (168 mapas), `ppp_map_event_flow_test.gd` e `ppp_genie_event_test.gd`. Em 20/10/2026, o Pool 1 passou em `ppp_campaign_identity_test.gd`, `ppp_campaign_modes_test.gd`, `ppp_playable_selection_test.gd` e `ppp_campaign_information_eligibility_test.gd`. Os avisos de limpeza de Resources ao encerrar os testes já ocorrem no ambiente e **não foram investigados nesta etapa**. Consulta central de elegibilidade e resumo pré-jogo existem; filtro do pool ativo em todos os consumidores, vitória/derrota e persistência continuam em etapas posteriores.
