# Livro de registros durante a partida — catálogo de frases

Este documento registra as decisões editoriais aprovadas pelo jogador. A entrada nasce apenas quando a ação termina e o resultado é conhecido. O livro imutável guarda `action_id`, IDs, ordem, contexto e segmentos coloridos; o texto não é chave de regra. Saves antigos não são reescritos. Se faltar dado para um fato que deveria constar, usar literalmente: **Trecho corrompido//arquivo perdido. ERRO de registro**.

## Decisões já aplicadas

| Ação | Forma de linha durante o jogo | Fonte |
| --- | --- | --- |
| Caminhada/reposicionamento comum | Não aparece. Registros antigos desse tipo também ficam ocultos na consulta, sem alterar seu arquivo. | `CampaignJournalRecorder`, `CampaignJournalUI` |
| Item encontrado | `[personagem] recolheu [item] encontrado em [distrito].` | `BlockManager.block_finished` |
| Revelação por ativa | `[personagem] usou [ativa] e revelou: [título do bloco].` Para vários, lista os títulos; o hex não aparece na frase. | `SkillManager.last_exploration_result.revealed_tiles` + conteúdo do mapa |
| Encontro Indesejado | `[personagem] caiu em um Encontro Indesejado com [nome do encontro].` | `CombatManager.combat_prepared` |
| Evento com aceite | `[personagem] ativou o Evento [nome]. Aceitou. [efeito concreto].` Recusa: `Recusou.` O aceite só é escrito no modo que oferece aceitar/recusar. | `EventData.resolution_mode`, `EventExecutor.result_ready` |
| Evento com opção | `[personagem] ativou o Evento [nome]. Escolheu [opção]. [efeito concreto].` Não atribuir “escolheu” a sorteio automático. | `EventData.resolution_mode`, `outcome_id` |
| Loja com escolha de item | `[personagem] ativou o Evento [loja]. Escolheu [item].` O item escolhido substitui a frase genérica do Outcome. | `decision.selected_catalog_item` |
| Ganho/perda numérico por Evento | `Ganhou/Perdeu [N] de Vida máxima/Ataque/Estamina máxima.` Para Vida atual positiva: `Recuperou [N] de Vida.` Valores vêm de `before`/`after` efetivos, após limites. | `result.effects` |

As cores seguem o livro existente: ator azul-ciano; hostil e perda vermelhos; item rosa; ativa azul; Informação e benefício verdes; nome de Evento lilás; restante branco/cinza legível. **CRITOU!** aparece em dourado e Informação obtida em verde, ambos com contorno/brilho leve. O título do bloco e o valor da consequência não são deduzidos de narrativa livre.

## Demais decisões aprovadas

| Tipo | Regra de exibição | Implementação |
| --- | --- | --- |
| Item consumido | `[personagem] consumiu [item] e recuperou [N] de Vida.` Se o alvo for outro, `em [alvo]`. Outros efeitos e chances descrevem o **resultado real**; não usar “efeito aplicado”. | `InventoryManager.use_consumable`; resultados negativos de chance que não ocorreram não abrem aviso. |
| Equipar / desequipar | `[personagem] equipou/desequipou [item].` Uma substituição direta gera **duas linhas**, saída antiga e entrada nova. | `EquipmentManager`, inclusive peça de aliado. |
| Transferir / descartar | **Não registrar.** Linhas legadas ficam ocultas na consulta, sem reescrever saves. | `InventoryManager`, `CampaignJournalUI`. |
| Criar Épico | `[personagem] criou [Épico] usando [N] [ingredientes].` A contagem é 2 com o EVA da Professora ou 3 no craft comum. | `EpicCraftPanel`. |
| Ataque / contra-ataque | `[atacante] atacou/contra-atacou [alvo] e causou [N] de dano.` Complementos só quando verdadeiros: esquiva, sangramento, atordoamento; no crítico, **CRITOU!** em dourado. | `CombatManager.action_resolved` informa dano, crítico e status; `CampaignJournalRecorder` constrói a frase. |
| Dado de Combate | **Não registrar o valor.** O dano efetivo basta. Linhas legadas ficam ocultas. | `CampaignJournalRecorder`, `CampaignJournalUI`. |
| Ativa em Combate | `[ator] usou [ativa] e [efeito concreto].` Só escreve `em [alvo]` quando o alvo é **outra entidade**, nunca quando é o próprio ator. | `SkillManager` entrega alvo selecionado e efeitos concluídos. |
| Ativa em Exploração não reveladora | `[ator] usou [ativa] e [efeito concreto].` Teleporte, movimento extra, destruição, posicionamento, saída temporária e item têm frases próprias; sem telemetria concreta, registrar só o uso, nunca inventar efeito. | `SkillManager.last_exploration_result`. |
| Evento automático/aleatório | `[ator] ativou o Evento [nome]. [resultado concreto].` Não usar “aceitou/escolheu” sem escolha. | `EventExecutor.result_ready`. |
| Encontro terminado | `O grupo venceu/perdeu o Encontro Indesejado: [nome do encontro].` O nome atravessa save/load de combate. | `CampaignJournalRecorder` e serialização. |
| Informação localizada | `O grupo encontrou a Informação: [título].` | A concessão central não fornece ator estável para todas as origens; usar **grupo** em vez de atribuir a pessoa errada. |
| Morte | `[personagem] morreu.` **Definitivo**, sem causa. | `CampaignState.playable_death_finalized`. |
| Recrutamento, promoção, ressurreição | Verbos distintos quando o sinal identifica cada estado. | `companion_registered` e `playable_slot_replaced`. |
| Virada de Rodada | **Não registrar como ação.** Dia/período/distrito permanecem no contexto de cada linha e no rodapé do livro. Linhas legadas ficam ocultas. | `CampaignJournalRecorder`, `CampaignJournalUI`. |

## Pontos técnicos para a próxima passada

- `scripts/campaign/campaign_journal_recorder.gd`: normalização de Eventos, Encontros, combate, ativas e contexto. O gravador não deve se antecipar a outcome pendente.
- `scripts/managers/inventory_manager.gd` e `scripts/managers/equipment_manager.gd`: consumo, transferência, descarte, equipar/desequipar; preservar IDs de cópia e alvo no `references`.
- `scripts/managers/event_executor.gd`: garantir `before`/`after`, tipo de atributo, item/entidade escolhidos e resultado de chance por efeito. Não usar texto narrativo como fonte de valor.
- `scripts/managers/skill_manager.gd` / `skill_effect_executor.gd` e `scripts/combat/combat_manager.gd`: retornar alvos e efeitos realmente aplicados, inclusive falha, status e invocações.
- `scripts/ui/campaign_journal_ui.gd`: apresenta sem reescrever arquivo; numera apenas linhas visíveis e conserva a ordem inversa de leitura.
- `scripts/campaign/campaign_save_repository.gd`: resumo arquivado continua uma projeção separada do livro detalhado; não reutilizar frase para decidir mecânica.

Pendência técnica real: resultados de ativas sem telemetria suficiente não devem ganhar texto inventado; cada novo efeito precisa devolver resultado concreto antes de receber frase própria. Os textos acima são a regra editorial atual, não propostas abertas.
