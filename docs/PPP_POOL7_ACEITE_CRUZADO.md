# Pool 7 — aceite cruzado da campanha 0.5

Data: 23/10/2026. Este relatório separa implementação, evidência automatizada e pendência; **não declara aceite final irrestrito**. A matriz C01–C18 vem da especificação funcional v0.5. As decisões posteriores do jogador prevalecem: Abandonar apaga slots, autosave e livro; a Campanha Completa usa todos os desfechos registrados, hoje quatro.

## Matriz da especificação funcional

| Caso | Resultado verificável | Teste principal |
| --- | --- | --- |
| C01 | Curta manual restringe Khainokata e vence na 5ª Informação única. | `ppp_campaign_modes_test.gd`, `ppp_campaign_pool2_test.gd` |
| C02 | Média manual mantém dois desfechos, dez partes válidas e recusa duplicatas. | `ppp_campaign_modes_test.gd`, `ppp_campaign_pool2_test.gd` |
| C03 | Média aleatória sorteia dois desfechos distintos e preserva a seleção ao carregar. | `ppp_pool7_cross_acceptance_test.gd` |
| C04 | Completa usa os desfechos registrados e vence na 20ª parte atual. | `ppp_campaign_modes_test.gd`, `ppp_campaign_pool2_test.gd` |
| C05 | Evento exclusivo inativo não entra no sorteio normal, inclusive secundário. | `ppp_campaign_pool3_test.gd`, `ppp_campaign_secondary_event_filter_test.gd` |
| C06 | Evento geral condicionado continua elegível; outcome consulta a Informação realmente obtida. **Contrato aprovado com fixture sintética**, pois ainda não existe um Resource geral de produção com esse caso exato. | `ppp_pool7_cross_acceptance_test.gd` |
| C07 | Encontro associado tematicamente continua elegível; recompensa de desfecho inativo é recusada sem substituir ID fixo. | `ppp_campaign_pool3_test.gd`, `ppp_campaign_information_eligibility_test.gd` |
| C08 | Três slots por campanha com IDs distintos; salvar em outro não altera os anteriores. | `ppp_save_codec_test.gd` |
| C09 | Sobrescrita exige confirmação; recusa conserva o slot anterior. | `ppp_save_codec_test.gd`, `ppp_pool5_load_confirmation_test.gd` |
| C10 | Load restaura mapa existente, posição, inventário, efeitos e estado de combate sem ressorteio; comparação semântica passou. | `ppp_save_codec_test.gd`, `ppp_save_combat_test.gd` |
| C11 | Noite → novo Dia oferece salvar uma vez; cancelar/não salvar não repetem a transição. | `ppp_round_manager_test.gd` |
| C12 | Sair sem salvar tem confirmação e cancelamento; backup descartado não reaparece como recuperação. | `ppp_pause_menu_test.gd`, `ppp_autosave_ui_test.gd` |
| C13 | Regra posterior à especificação: Abandonar confirmado remove os três slots, autosaves e livro; Arquivar preserva o histórico. | `ppp_pause_menu_test.gd`, `ppp_campaign_archive_test.gd` |
| C14 | Derrota ocorre apenas quando não há jogáveis vivos/substitutos humanos; ausência temporária não é morte. | `ppp_campaign_pool2_test.gd`, `ppp_death_replacement_test.gd` |
| C15 | Debug distingue execução normal/forçada sem poluir pool normal nem remover hex existente. | `ppp_debug_panel_test.gd` |
| C16 | Falha real de escrita é comunicada e conserva o último slot válido; arquivo incompatível/corrompido é recusado. | `ppp_pool7_cross_acceptance_test.gd`, `ppp_save_codec_test.gd` |
| C17 | Vitória provisória depende apenas das Informações válidas, sem chefe, Trena ou mapa especial. | `ppp_campaign_pool2_test.gd`, `ppp_final_center_map_test.gd` |
| C18 | Novo Jogo não ocupa/sobrescreve outro slot nem impõe cota de campanhas. | `ppp_save_codec_test.gd`, `ppp_campaign_identity_test.gd` |

## Casos adicionais obrigatórios

| ID | Verificação | Evidência |
| --- | --- | --- |
| D01–D04 | Eventos diretos 01 Artefato do Vazio, 02 Cobaia Secreta, 03 O Velho Louco e 04 Termos de Uso: ausentes em curta/média mesmo com desfecho ativo; elegíveis na completa. | `ppp_campaign_pool3_test.gd`, `ppp_campaign_secondary_event_filter_test.gd` |
| I01 | 17 O Informante ausente dos sorteios normais curta/média. | `ppp_campaign_pool3_test.gd` |
| I02 | 44 Duas-Caras ausente dos sorteios normais curta/média. | `ppp_campaign_pool3_test.gd` |
| I03 | 49 Gênio permanece no pool, mas desejo de Informação não é oferecido na curta/média. | `ppp_genie_event_test.gd`, `ppp_campaign_pool3_test.gd` |
| I04 | Na completa, o desejo de Informação continua oferecido. | `ppp_genie_event_test.gd` |
| I05 | Concessões indiretas/forçadas respeitam partes novas e desfechos ativos; ID fixo inválido não é trocado por outro. | `ppp_campaign_pool3_test.gd`, `ppp_campaign_information_eligibility_test.gd` |
| R01 | Cada mapa conserva uma Informação fixa e no máximo uma livre. | `ppp_campaign_pool2_test.gd`, `ppp_final_center_map_test.gd` |
| R02 | Avanço regular exige Informação obtida no mapa atual. | `ppp_round_manager_test.gd`, `ppp_campaign_pool2_test.gd` |
| R03 | Curta vence em 5, média em 10; duas partes no mesmo mapa antecipam a conclusão. A curta foi exercitada até vitória no quarto mapa. | `ppp_campaign_pool2_test.gd`, `ppp_pool7_cross_acceptance_test.gd` |
| R04 | Portal e Abdução podem gerar mapas extras, mas não elevam meta nem bloqueiam por número de mapas. | `ppp_world_event_transition_test.gd` |
| E01–E02 | Curta sem Orchestra: abaixo de 2 pistas globais sem oferta; a partir de 2, chance fixa de 50%. | `ppp_a_experiencia_recruitment_test.gd` |
| E03–E04 | Média sem Orchestra: abaixo de 4 sem oferta; a partir de 4, chance fixa de 50%. | `ppp_a_experiencia_recruitment_test.gd` |
| E05–E07 | Com Orchestra ativa, o global não substitui as pistas específicas: nenhuma = sem oferta; 2/5 ou 3/5 = 50%; ambas = 75%, inclusive com contagem global alta. | `ppp_a_experiencia_recruitment_test.gd` |
| E08 | Completa mantém regra Orchestra original; recusa, sucesso, falha, ativador e Encontro único são preservados. | `ppp_a_experiencia_recruitment_test.gd` |
| S01 | Autosave efetivo nos três gatilhos: Informação, virada de Rodada e vitória sinalizada em combate. | `ppp_pool7_cross_acceptance_test.gd`, `ppp_autosave_test.gd` |
| S02 | Backup íntegro é recuperável e restaura estado sem ocupar slot manual. | `ppp_pool7_cross_acceptance_test.gd`, `ppp_autosave_ui_test.gd` |
| S03 | Recuperação pede escolha explícita de um dos três slots; nenhum é sobrescrito automaticamente. | `ppp_autosave_ui_test.gd` |

## Execução e ressalvas

Passaram nesta rodada, com saída de sucesso: `ppp_campaign_modes_test.gd`, `ppp_campaign_pool2_test.gd`, `ppp_campaign_pool3_test.gd`, `ppp_pool7_cross_acceptance_test.gd`, `ppp_world_event_transition_test.gd`, `ppp_save_codec_test.gd`, `ppp_equipment_source_save_test.gd` (três execuções), `ppp_action_button_palette_test.gd`, `ppp_game_hud_palette_test.gd`, `ppp_event_executor_test.gd`, `ppp_genie_event_test.gd` e `ppp_party_status_hud_test.gd` (0 falhas após atualização). O teste do executor antes emitia erros apesar do código zero; após remover o pré-carregamento circular, não emitiu erros de cena ou script. Restam avisos de Resources em uso na finalização do processo de teste. Os demais testes citados na matriz haviam passado no primeiro lote desta etapa, antes das duas correções adicionais de mochila e botões; não foram todos repetidos depois delas.

Limitações que impedem declarar o aceite final encerrado:

1. A repetição final de `ppp_a_experiencia_recruitment_test.gd` demorou além da janela de execução e foi interrompida. O lote inicial havia terminado com **0 falhas**, mas esta repetição não pode ser contabilizada como novo passe. É necessário repetir de modo isolado antes do aceite final.
2. C06 usa um Evento geral de teste criado em memória, não uma ficha de produção. Para fechar cobertura de conteúdo, um Resource real futuro que use a mesma condição deverá entrar na suíte.
3. Os testes são automatizados e não substituem inspeção visual nem campanha manual curta/média/completa até o fim. Avisos de objetos/Resources ainda em uso aparecem no encerramento de alguns testes; não são prova de falha funcional, mas pedem limpeza da infraestrutura de teste.

## Correções adicionais recebidas durante a Pool 7

- O bônus da Mochila cor de Rosa agora usa uma origem de equipamento persistente no save. Ao trocar pelo Passa-tempo depois de carregar, o Pedreiro fica com **12/12**, não 12/15. O carregamento religa a origem de saves antigos e remove concessões órfãs de saves já afetados, sem alterar `ItemData` compartilhado. Coberto por `ppp_equipment_source_save_test.gd` e regressão de `ppp_save_codec_test.gd`.
- Na paleta **Padrão** apenas, Ativas clicáveis dos jogáveis usam amarelo, Jogar Dado/Atacar/Reposicionar e ações de movimento de combate usam verde neon leve, e Passar Turno sem ações centrais usa vermelho escuro. Texto escuro no amarelo/verde e claro no vermelho passou razão de contraste ≥ 4,5:1 em normal, hover e pressionado. Botões indisponíveis continuam no estilo desabilitado. As três outras paletas mantêm os papéis de cor anteriores; o isolamento e a troca dinâmica passaram em `ppp_action_button_palette_test.gd` e `ppp_game_hud_palette_test.gd`.
- A ficha do Gênio deixou de ser pré-carregada durante a análise do script do popup; a cena é carregada somente ao abrir essa ficha. Isso eliminou a falha circular de carregamento do HUD no teste de Eventos. `ppp_event_executor_test.gd` e `ppp_genie_event_test.gd` passaram após a mudança.
- O teste da HUD agora isola paleta/escala, aceita opacidade mínima de 80% e valida a lista e as ações independentes do aliado na Exploração, em vez da caixa-filho obsoleta. `ppp_party_status_hud_test.gd` chegou ao fim com 0 falhas.

Arquivos alterados nesta etapa: `scripts/tests/ppp_pool7_cross_acceptance_test.gd`, `scripts/tests/ppp_world_event_transition_test.gd`, `scripts/tests/ppp_equipment_source_save_test.gd`, `scripts/tests/ppp_action_button_palette_test.gd`, `scripts/tests/ppp_party_status_hud_test.gd`, `scripts/campaign/inventory_item_state.gd`, `scripts/campaign/campaign_save_codec.gd`, `scripts/managers/equipment_manager.gd`, `scripts/managers/skill_manager.gd`, `scripts/ui/party_status_hud.gd`, `scripts/ui/ui_palette_manager.gd`, `scripts/ui/block_activation_popup.gd` e este relatório. Não houve alteração de catálogo de desfechos, sprites ou cena do mundo por essas correções.
