# Leva 0.5 — drops pós-combate e último mapa no Centro

**Estado:** regras implementadas e verificadas por testes headless da Leva 0.5. A inspeção visual em jogo e o playtest de economia continuam úteis; não são bloqueios de integração. A especificação `PPP_Especificacao_Drops_Informacoes_Centro.docx` foi lida integralmente. Não modificar o documento-fonte.

## Regras vigentes

| Distrito onde o combate foi vencido | Chance única por combate | Quantidade se o sorteio tiver sucesso |
| --- | ---: | ---: |
| Subúrbio | 60% | 1 |
| Baixo-Centro | 80% | 1 ou 2, com pesos iguais |
| Centro | 100% | **3 no total**: dois itens regulares e o terceiro um Consumível garantido |

- Só há saque de combate quando algum hostil foi efetivamente vencido. Recrutamento ou encerramento sem luta não produz esse drop; prêmios próprios de Eventos continuam independentes.
- Cada item regular é sorteado entre **Equipável comum (50%)** e **Consumível (50%)**. No Centro, essa distribuição vale para os dois primeiros; o terceiro é sempre Consumível. Equipáveis Épicos e amaldiçoados nunca entram. Dentre os Consumíveis, a chance de Raro é **2%**; apenas Resources raros elegíveis entram no catálogo `ENEMY_LOOT`. As escolhas dentro de cada subgrupo são aleatórias.
- **Subúrbio e Baixo-Centro:** se o dano efetivo acumulado sofrido pelos integrantes presentes no combate for **estritamente maior** que 40% da soma de suas Vidas máximas registradas na entrada, acrescentar exatamente **um Consumível**, mesmo quando o sorteio regular falhar. Cura não apaga dano recebido. Companheiros temporariamente ausentes não aumentam o limiar; morte durante o combate não retira o participante do denominador. **Centro:** o terceiro item é a garantia de Consumível independentemente desse limiar; nunca há quarto item por dano.
- Sortear uma vez, guardar o resultado e entregar com confirmação. Sem espaço, permitir distribuição/troca ou recusa explícita; nunca declarar recebido um item que não entrou no inventário. Preservar itens de recompensa específicos de Eventos.
- Não alterar percentuais ou capacidade com base apenas em projeção. O usuário considera viável a economia de 36 espaços principais, equipamentos adicionais, consumo frequente de cura e craft; rebalancear só após playtest.

## Centro na Campanha Completa

**Não existe Informação exclusiva do Centro nem reserva de um ID por desfecho.** Todas as partes ainda não obtidas dos desfechos ativos continuam disponíveis pelas regras centrais de concessão e geração. A meta é 20 Informações válidas para os quatro desfechos atuais, modular se novos desfechos forem cadastrados.

O mapa gerado quando o grupo já tem **18 ou 19 de 20 Informações** mantém exatamente **um hex fixo de Informação**: hexes livres não podem sortear outro. Assim, o mapa que pode render a 19ª parte não antecipa a 20ª por um segundo hex. Essa restrição é só da Campanha Completa; não bloqueia concessões extras por Evento, acessório ou outra fonte válida.

Quando a Completa estiver com **19 de 20 Informações** e ocorrer **a próxima troca de mapa**, o destino é obrigatoriamente um **novo mapa no Centro**, qualquer que fosse o distrito de origem ou o destino pedido por avanço regular, Portal, abdução ou Evento. Enquanto a campanha permanecer com 19, transições posteriores também ficam no Centro. A introdução narrativa é mostrada só na primeira chegada forçada e seu estado deve sobreviver a save/load. Não mudar de mapa imediatamente ao receber a 19ª Informação.

Provisoriamente, a transição usa uma cena intermediária preta, com área reservada para imagem/cutscene futura e texto: “Os outros lugares da cidade foram destruídos. Estamos agora no Centro de Belacidade... O que acontece agora?”. Essa cena não deve ficar sobre o mapa ou disputar o foco com outra transição, inclusive na virada de Dia.

A 20ª Informação pode ser obtida **antes** dessa troca por bônus de Evento, acessório ou outra fonte extra válida — **não por um segundo hex livre** no mapa da reta final. Nesse caso, a vitória acontece no mapa atual e não se força uma visita ao Centro. Isso é uma exceção aceita, não um erro nem motivo para bloquear a concessão. No mapa final do Centro, a Informação fixa padrão pode conceder a 20ª. Também não há cota de mapas: a vitória depende de Informações, não de quantidade de cenários visitados.

## Integração verificável

| Sistema | Trabalho necessário |
| --- | --- |
| `CampaignState`, `GerenciaJogo` e gerador | Consultar 19/20 pelo estado de campanha, centralizar o destino Centro, impedir a Informação livre desde 18/20 e persistir se a introdução já ocorreu. Jamais usar título de Informação como chave. |
| `RoundManager`, `EventExecutor` e demais trocas | Passar pelo mesmo resolvedor de destino antes de gerar/instalar o mapa; não permitir distrito alternativo por caminho secundário. Não forçar um mapa se a 20ª Informação já encerrou a campanha. |
| Cena de transição e `CampaignTopBar` | Mostrar preto integral, texto provisório e botão de continuar, com fila/ordem previsível se coincidir com a transição Noite → novo Dia. |
| `CombatManager`, `SkillManager` | Capturar participantes e Vidas máximas, somar Vida realmente perdida por instância de combate, rolar o saque uma vez após vitória elegível e guardar o resultado. |
| `InventoryManager`, `BlockActivationPopup` | Filtrar catálogo por origem/tipo/raridade, exibir lote e resolver destino de todos os itens antes de registrar o recebimento. |
| Save e registros | Persistir contador de dano, RNG/resultado já sorteado, entrega pendente e introdução do Centro; não rerrolar ou duplicar itens ao carregar. Registrar apenas a entrega efetiva. |

## Aceite

1. Mapas gerados com 18/20 ou 19/20 têm só uma Informação fixa, sem segunda Informação livre. Aos 19/20, avanço normal, Portal, abdução e `CHANGE_MAP` levam a **novo mapa do Centro**; save/load e segunda transição não repetem a introdução nem liberam outro distrito. Aos 20/20 obtidos por fonte extra antes da troca, vitória sem mapa adicional.
2. Um combate com vários inimigos gera uma única rolagem regular. No Subúrbio/Baixo-Centro, 40% exatos não dão Consumível extra; mais de 40% dão um, mesmo se o drop regular falhar. Cura no meio da luta não reduz o acumulado. No Centro, o terceiro Consumível é garantido até com dano zero; ultrapassar 40% não cria um quarto item.
3. Distribuição observada: 60/80/100% por distrito, quantidades corretas, 50/50 nos slots livres entre Equipável comum e Consumível, e 2% de Raro condicionado a Consumível. Nenhum Épico ou amaldiçoado cai como saque comum.
4. Recrutamento sem hostil vencido não gera saque. Inventário cheio exige decisão consciente. Estado de combate anterior à conclusão sobrevive a save/load; pedido de save enquanto a janela de recompensa está aberta aguarda o próximo limite estável. O lote já sorteado é serializável e a reentrada na vitória não o sorteia novamente.

**Regressões executadas:** `ppp_combat_loot_test.gd`, `ppp_combat_turn_test.gd`, `ppp_combat_entry_test.gd`, `ppp_save_combat_test.gd`, `ppp_save_codec_test.gd`, `ppp_final_center_map_test.gd` e `ppp_final_center_transition_test.gd`. Reexecutar após mudar saque, transição, inventário ou codec. Avisos de recursos no encerramento headless são anteriores a esta leva e não significam falha dos asserts.

