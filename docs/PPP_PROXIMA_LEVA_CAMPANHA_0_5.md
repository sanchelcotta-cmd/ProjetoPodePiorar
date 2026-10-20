# Próxima leva de trabalho — campanha 0.5

Plano de execução para modos de campanha, desfechos, Informações, persistência, menus e depuração. Este arquivo organiza o trabalho; **não declara essas funcionalidades implementadas**. A especificação funcional v0.5 foi lida integralmente, incluindo seus cinco quadros e a matriz C01–C18. As decisões mais recentes do jogador abaixo prevalecem quando divergem do texto-base.

## Decisões fechadas para esta leva

| Contexto | Regra a implementar |
| --- | --- |
| Campanha curta | Um desfecho ativo, escolhido ou sorteado com peso igual entre os quatro; meta de cinco Informações únicas válidas. |
| Campanha média | Dois desfechos ativos diferentes, escolhidos ou sorteados sem reposição e com peso igual; meta de dez Informações únicas válidas. |
| Campanha completa | Os quatro desfechos ativos automaticamente; meta de vinte Informações únicas válidas. |
| Duração por mapas e Rodadas em curta/média | Preservar a regra-base: cada mapa traz **1 hex de Informação garantido**, podendo trazer **mais 1** no sorteio de blocos livres; a transição regular de Rodada já exige obter Informação do mapa atual. No percurso regular, bastam **até 5 mapas/Rodadas** na curta (um Dia e meio) e **até 10** na média, podendo terminar antes com duas Informações no mesmo mapa. Portal, abdução ou outra troca especial de mapa **não aumenta a meta** de 5/10 Informações; não limitar o número total de cenários visitados por esses efeitos. |
| Eventos **diretos** | Em campanhas **curtas e médias**, não entram no sorteio normal **mesmo que seu desfecho relacionado esteja ativo**. Na completa, seguem as demais regras de elegibilidade. Os quatro casos já identificados são 01 Artefato do Vazio, 02 Cobaia Secreta, 03 O Velho Louco e 04 Termos de Uso. Auditar o catálogo antes de fechar a lista. |
| Eventos **indiretos** e recompensas | Toda Informação concedida ou sorteada deve vir **somente do pool de desfechos ativos** e ainda não ter sido obtida, inclusive quando uma fonte for forçada por depuração. A classificação indireta não garante que o Evento seja elegível em todos os modos. |
| 17 O Informante e 44 Duas-Caras | **Excluir ambos do sorteio normal em campanhas curtas e médias.** Na completa, permanecem elegíveis pelas regras normais; suas recompensas de Informação ainda passam pela validação central. A exclusão vale também para sorteios encadeados e blocos livres. |
| 49 Gênio da Lâmpada | **Manter o Evento elegível** em todos os modos. Em curta e média, ocultar/indisponibilizar apenas o desejo de ganhar Informação aleatória; os demais desejos aplicáveis continuam. Na completa, o desejo de Informação permanece disponível e usa o pool de desfechos ativos. |
| A Experiência em campanha curta **sem Orchestra selecionada** | Com **duas ou mais** Informações já obtidas do desfecho ativo, oferecer uma tentativa pré-combate de recrutamento com **50% fixos**. Abaixo do limiar, inicia o combate sem oferta. |
| A Experiência em campanha média **sem Orchestra selecionada** | Com **quatro ou mais** Informações já obtidas dos desfechos ativos, oferecer a mesma tentativa com **50% fixos**. Abaixo do limiar, inicia o combate sem oferta. |
| A Experiência em campanha curta ou média **com Orchestra entre os desfechos selecionados** | Usar **somente** o outcome original: Orchestra 2/5 **ou** 3/5 obtida dá 50%; ambas dão 75%; nenhuma não oferece tentativa. A contagem global de 2/4 não substitui nem complementa esta condição. |
| A Experiência em campanha completa | Preservar o mesmo outcome original baseado em Orchestra 2/5 e 3/5. A entidade continua sendo um Encontro único em todos os modos. |

**Precedência importante.** O §4.2 da especificação propõe, para A Experiência sem Orchestra ativo, usar o teto de chance do Resource. A decisão posterior **substitui** essa proposta por 50% fixos após 2/4 Informações em curta/média **apenas quando Orchestra não estiver selecionada**. Se Orchestra estiver selecionada, vale o outcome original, independentemente da contagem total de Informações. O mesmo §4.2 descreve a exclusividade de eventos por desfecho ativo; para os **diretos**, a decisão posterior é mais restritiva e os exclui inteiramente de curtas e médias. Não estender a exceção de A Experiência automaticamente a outros encontros sem uma regra específica.

**Ritmo de campanha.** Retirar 17, 44 e o desejo de Informação do 49 simplifica os resultados e evita que 44 apague progresso em campanhas curtas/médias. No fluxo regular, a Informação fixa por mapa sustenta a conclusão em até **5/10 mapas**; o segundo hex de Informação livre pode antecipá-la. Portais e abduções podem levar o grupo a mapas extras, mas **não acrescentam Informações à meta**. Não compensar a exclusão dos Eventos com novos prêmios ou cotas inventadas. Os seis Eventos excluídos em curta/média (01–04, 17 e 44) são atualmente de valência ambígua, portanto a suficiência dessa valência deve ser verificada após o filtro.

**Decisão para standby e caminhos secundários.** Se faltar uma valência obrigatória, liberar o Evento em standby mais antigo **da valência necessária**, sem trocar por outra. Se ainda faltar candidato, falhar sem instalar mapa parcial. O filtro dos seis Eventos exclusivos também vale na recomposição de hexes do Saci (41), em Eventos encadeados e nos filhos gerados por outro Evento. Um ramo opcional com filho inelegível sai antes do sorteio; se não restar resultado, bloquear o pai sem alterar o mapa. Depuração forçada será uma exceção explícita no Pool 6. Nada disso deve aparecer na descrição narrativa de um outcome.

**Metadados e filtro já ligados.** Os Resources dos Eventos 01–04, 17 e 44 carregam a tag estável `somente_campanha_completa` em `EventData.tags`; ela restringe o Evento inteiro. O Resource 49 carrega `contem_outcomes_restritos_por_modo`, e somente seu outcome `random_information` carrega `somente_campanha_completa` em `EventOutcomeData.tags`. Tags temáticas antigas foram preservadas. `EventCampaignEligibility` já aplica a restrição ao gerador, Saci, encadeamentos, filhos gerados, executor e UI do Gênio. O modo já é escolhido na tela inicial e guardado em `CampaignState.campaign_mode`; Completa permanece como padrão. Não inferir elegibilidade pelo nome, descrição ou tags temáticas.

## O que já está sanado e deve ser reutilizado

Estes pontos foram constatados nos arquivos e testes existentes. Eles **não** precisam ser refeitos; as novas regras ainda exigem integração e regressão:

- As quatro séries possuem 20 Resources de Informação, com `id`, `tipo`, número e tags. `CampaignState` já mantém IDs obtidos e sua ordem; revelar um hex não equivale a obter sua Informação. Falta restringir a obtenção aos desfechos ativos e rejeitar duplicatas na interface central.
- O fluxo básico Manhã → Tarde → Noite, a transição de mapa, os três jogáveis selecionados e o sorteio dos demais integrantes até completar o trio já existem. A tela seleciona modo/desfechos ou pede sorteio e agora exibe o resumo preto antes de gerar o mapa. A consulta de elegibilidade por Informação está no modelo; falta conectá-la a cada origem de sorteio/concessão no Pool 2.
- O gerador já preserva cotas de 40 hexes, **1 Informação fixa e no máximo mais 1 via bloco livre**, valências, limites por Resource, espera de Eventos, restrições de Armadilhas/Catástrofes e exclusão de Encontros únicos já ocorridos. O avanço regular de Rodada já exige Informação obtida no mapa atual. Quando falta capacidade obrigatória, a geração devolve falha explícita. Falta aplicar a nova elegibilidade por modo/desfecho **em todos os caminhos de sorteio**, sem contornar cotas silenciosamente.
- Os outcomes atuais dos eventos diretos 01–04 e os mecanismos dos eventos indiretos 17, 44 e 49 já têm execução registrada em `EVENTOS_EXECUCAO_PROVISORIO.md`. Falta a filtragem por modo e a validação central da recompensa; não reescrever narrativa nem refazer seus effects por padrão.
- A Experiência já oferece escolha pré-combate, aplica o sorteio de 50%/75% conforme Orchestra 2/5 e 3/5, converte a própria entidade em aliada do ativador no sucesso e inicia o combate na recusa/falha. O Encontro já está marcado como único e o gerador exclui sua repetição após conclusão. **Faltam a ramificação por presença de Orchestra nas seleções da campanha, a regra alternativa sem Orchestra em curta/média e a mensagem contextual.**
- Personagens, inventários, condições, efeitos temporários, mapa e combate mantêm estado em instâncias de campanha, sem usar o `.tres` como progresso mutável. Há também restauração dos ausentes no evento de isolamento; a regra terminal de derrota da v0.5 ainda precisa de integração e teste próprio.

**Não tratar como sanado:** integração universal da consulta de elegibilidade com sorteios/concessões de Informação; vitória em 5/10/20; catálogo de campanhas e três slots; save/load/autosave; menus inicial/pausa; convite ao fim do Dia; painel de depuração. Não foi encontrado um `SaveManager` de jogo operacional — a referência de API em `docs/pro_api_reference.md` não demonstra implementação no fluxo atual.

## Pools em ordem de prioridade e dependência

Cada pool só é considerado concluído com implementação, teste de aceite e atualização deste plano. A ordem respeita as etapas A–G da especificação, mas intercala testes locais para que regressões sejam detectadas imediatamente.

### Pool 0 — Auditoria de integração e inventário de dados  |  prioridade bloqueante  |  etapa A

1. Inventariar `CampaignState`, `GerenciaJogo`, gerador, `RoundManager`, `BlockManager`, `EventExecutor`, `CombatManager`, telas e todos os pontos que concedem, removem ou sorteiam Informação; localizar persistência real, se houver fora dos caminhos já inspecionados.
2. Produzir uma matriz por Resource/ID de Evento: desfecho específico, dependência direta/indireta, condição, outcome, concessão de Informação, categoria, peso e elegibilidade por modo. Cobrir também eventos criados por outros eventos e recompensas de Encontros; menção narrativa/tag temática **não** basta para classificar dependência.
3. Comparar os campos realmente existentes com os metadados necessários. Registrar IDs inválidos/duplicados, referências órfãs, categorias que podem esvaziar e conflitos de decisões antes de alterar `.tres`.

**Auditoria registrada:** `PPP_POOL0_MATRIZ_EVENTOS.md` inventaria 85 Eventos, 20 Informações, 36 Encontros, rotas de concessão, referências e riscos; `scripts/tests/ppp_pool0_resource_audit.gd` reproduz a leitura. A restrição por tag passou nos testes de mapa, Saci, filhos gerados, encadeamento e Gênio; a escolha real de modo foi ligada no Pool 1. O mapa de arquivos e palavras-chave para os próximos pools está em `PPP_PENDENCIAS_INTEGRACAO_CAMPANHA_0_5.md`. Ainda faltam pools ativos de Informação e cenários de campanha longa.

**Saída:** inventário verificável e lista curta de decisões bloqueantes. **Portão:** nenhuma regra nova depende de nome exibido ou texto narrativo.

### Pool 1 — Identidade, modos e desfechos da campanha  |  prioridade máxima  |  etapa B

1. Acrescentar identidade estável, versão de esquema, modo, desfechos ativos e estado terminal ao modelo de campanha, sem duplicar o estado dos subsistemas existentes.
2. Criar seleção/sorteio de um, dois distintos ou quatro desfechos com pesos iguais; sortear **uma única vez** ao criar a campanha e guardar o resultado. Validar quantidade exata, ausência de duplicidade e correspondência da meta 5/10/20.
3. Expor uma consulta única de elegibilidade por ID/tipo de Informação e por desfecho ativo, independente da UI. Integrar o modo à seleção de personagens e ao resumo preto pré-jogo somente depois de validar o modelo.

**Item 1 implementado no modelo:** `CampaignState` agora cria um UUID v4 por partida válida, registra `schema_version = 1`, mantém `campaign_mode` e os IDs dos desfechos ativos, e distingue partida não iniciada, ativa, vitória e derrota. Completa é o padrão quando o modo não é informado. `mark_terminal` impede sobrescrever um resultado, mas vitória/derrota reais ainda **não** estão conectadas; save/load também não está implementado. `ppp_campaign_identity_test.gd` cobre identidade, reinício, seleção inválida e estado terminal.

**Item 2 implementado:** a tela inicial oferece Curta, Média e Completa. Só Curta/Média exibem os quatro botões de desfecho e `Sortear`; escolha manual exige exatamente 1/2 IDs distintos, e o sorteio uniforme sem reposição é executado uma única vez em `CampaignState.start_new_game`. Completa ativa os quatro automaticamente. A meta 5/10/20 é derivada do modo, não guardada como estado duplicado. O resultado fica em `active_ending_ids` e não muda ao avançar Dia/mapa; persistência em disco permanece para o Pool 4. A UI usa linhas próprias acima dos cartões; em janela estreita os desfechos passam a duas linhas sem sobreposição de áreas de clique. `ppp_campaign_modes_test.gd` cobre validação, sorteio determinístico, ligação da UI à campanha e geometria em 800×600.

**Item 3 implementado no modelo e na entrada:** `InformationCampaignEligibility` indexa os Resources por `Informacao.id`, identifica o desfecho pela tag estável e confere `tipo`; título/descrição nunca são chaves. `CampaignState.is_information_eligible(id, tipo)` é a consulta única para consumidores sem dependência da UI. As partes 4/5 de Controle da Mente tiveram o `tipo` corrigido para concordar com ID/tag. `ppp_campaign_information_eligibility_test.gd` verifica os 20 IDs, divergências e filtros por desfecho ativo. Após a campanha ser criada, a seleção mostra uma revisão preta com modo, meta, desfechos efetivamente sorteados/escolhidos e equipe; só “Iniciar campanha” gera o primeiro mapa. Voltar sem alterar escolhas preserva a mesma campanha e o mesmo sorteio. **Não confundir consulta disponível com filtro já conectado:** todas as rotas de geração e concessão continuam no Pool 2.

**Portão:** testes determinísticos para sorteio, seleção manual, recarregamento sem novo sorteio e campanha completa; nenhum mapa ou evento deve escolher desfechos por conta própria.

### Pool 2 — Informações válidas e encerramento  |  prioridade máxima  |  depende do Pool 1  |  etapa B

1. Fazer **todas** as origens passarem por uma operação central de concessão: hex, eventos, encontros, habilidades, recompensas e depuração. Em jogo normal, recusar desfecho inativo e Informação repetida; retornar motivo explícito sem trocar por outra arbitrariamente.
2. Filtrar o catálogo de Informações antes de gerar o mapa, somente por desfechos ativos e partes ainda não obtidas. **Preservar**, não recriar, a Informação fixa por mapa, o possível segundo hex de Informação livre e a exigência de Informação para o avanço regular. `CHANGE_MAP`, Portais e abduções não devem elevar a meta de 5/10 nem ser bloqueados por uma suposta cota de mapas. Se não houver capacidade, falhar sem corromper a Rodada atual e sem criar partes inativas/duplicadas.
3. Depois de cada concessão válida, verificar vitória **uma única vez**, exatamente na quinta, décima ou vigésima Informação conforme o modo. Reservar extensão para futuros chefes, mas não implementá-los agora.
4. Integrar derrota ao sistema real de morte. Ausência temporária não conta como morte; se o isolado morrer, devolver os demais e continuar com sobreviventes. Bloquear continuação acidental em estado terminal.

**Portão:** concessões de todas as origens produzem a mesma decisão; falhas preservam efeitos independentes; vitória/derrota não disparam duas vezes nem dependem de chefes. No percurso regular, curta não precisa de um sexto mapa/Rodada e média não precisa de um décimo primeiro; duas Informações no mesmo mapa podem concluir antes. Mapas extras causados por efeitos especiais não alteram a meta de Informações.

### Pool 3 — Classificação, sorteios e A Experiência  |  prioridade alta  |  depende dos Pools 1–2  |  etapa C

1. Registrar dependências por IDs estáveis no Resource ou em catálogo validado; distinguir exclusividade direta, condição por Informação, concessão de Informação e Encontro associado, inclusive no nível de outcome quando mistos.
2. Excluir todos os **diretos** e também **17 O Informante** e **44 Duas-Caras** do pool normal de curta/média. Aplicar o filtro antes do sorteio em blocos por valência, blocos livres, eventos encadeados e demais entradas normais. Na completa, 17 e 44 seguem elegíveis. Manter pesos originais **entre elegíveis**; não inventar fallback se uma valência ficar vazia.
3. Em curta/média, manter **49 Gênio da Lâmpada** no pool, mas não montar nem aceitar a opção de desejo de Informação. Preservar seus outros desejos conforme a disponibilidade própria de cada um. Na completa, manter a opção de Informação.
4. Fazer toda concessão **indireta ainda permitida** sortear somente Informação nova do pool de desfechos ativos, inclusive se 17/44 forem forçados por depuração. Se a fonte tiver regra de seleção própria, conciliá-la com essa restrição; não substituir silenciosamente um ID fixo inválido.
5. Na oferta pré-combate de **A Experiência**, primeiro verificar se Orchestra está entre os desfechos selecionados. **Se sim**, em qualquer modo aplicar apenas a regra original das pistas Orchestra 2/5 e 3/5 (50% com uma; 75% com ambas). **Se não**, em curta/média aplicar respectivamente os limiares globais 2/4 e 50% fixos. Manter o vínculo ao ativador, o outcome de sucesso/falha, a recusa e a unicidade. O diálogo deve explicitar se a chance veio das pistas Orchestra ou da contagem global.
6. Encontros apenas associados tematicamente a uma série continuam elegíveis, salvo dependência mecânica expressa. Bloquear apenas a recompensa de Informação inativa, preservando consequências independentes.

**Portão:** matriz curta/média/completa para 01–04, 17/44/49 e A Experiência; 17/44 ausentes de todos os sorteios normais de curta/média, desejo de Informação ausente do Gênio nesses modos e presente na completa; teste de valência/pool vazio; nenhum evento excluído reaparece por caminho secundário.

### Pool 4 — Persistência confiável e restauração  |  prioridade alta  |  depende dos Pools 1–3  |  etapa D

1. Criar catálogo de campanhas e **três slots manuais por campanha**, com IDs distintos de campanha/slot. Novo Jogo não ocupa nem sobrescreve slot existente. Salvar em outro slot não altera os anteriores.
2. Versionar e serializar o estado efetivamente jogável: modo/desfechos, Informações e ordem, personagens e companheiros, morte, inventários/equipamentos/Skills, efeitos e prazos, Dia/Rodada/Distrito, mapa/hexes, decisões, encontros únicos, RNG e resultados já sorteados. Testar igualdade semântica antes/depois do carregamento; não regenerar o mapa a partir da seed.
3. Gravar primeiro em arquivo temporário validado, substituindo somente o slot confirmado por operação segura. Rejeitar formato incompatível/corrompido e preservar o último save válido.
4. Criar autosave oculto de recuperação nos três gatilhos definidos: virada de Rodada, Informação obtida e vitória em combate. Distingui-lo dos três slots manuais; expor recuperação com data/hora na tela de carregamento após interrupção forçada.
5. Definir tecnicamente se combate e modais transitórios são serializáveis. Até haver equivalência comprovada, bloquear salvamento nesses estados com mensagem clara, sem prometer retomada no meio da ação.

**Portão:** restauração em slot 1/2 independente, overwrite cancelado intacto, falha de I/O sem destruição, autosave recuperável e nenhuma rerrolagem por carregar.

### Pool 5 — Menus, confirmações e fim de Dia  |  prioridade alta  |  depende do Pool 4 para salvar/carregar  |  etapa E

1. Menu inicial: Novo Jogo, Carregar Jogo com campanhas/slots e dados úteis, Configurações provisórias com retorno funcional. Integrar resumo de modo, desfechos, meta e personagens.
2. Pausa: Continuar, Salvar, Configurações provisórias, Sair e Abandonar campanha. Separar semanticamente Sair de Abandonar; destruição de slots exige confirmação específica.
3. Solicitar save uma única vez na passagem efetiva Noite → novo Dia; Sim abre seletor de slots, Não prossegue sem salvar, cancelar segue fluxo previsível. Não repetir transição nem gerar mapa extra.
4. Mensagens de sobrescrita, alterações não salvas, perda de progresso, sucesso/erro real, campanha concluída e estado terminal. Exibir “Salvo” somente após gravação comprovada. Distinguir visualmente cancelar, sair e excluir.

**Portão:** testes de navegação, cancelamento e estado após retorno; nenhum botão simula funcionalidade inexistente.

### Pool 6 — Depuração interna controlada  |  prioridade média  |  depende dos serviços reais  |  etapa F

1. Painel visível apenas em desenvolvimento/flag explícita, ausente da exportação pública. Reutilizar operações reais para Eventos, Itens, Encontros, atributos, efeitos, Informações e tempo.
2. Exibir elegibilidade e motivo do bloqueio; forçar conteúdo excluído só em debug, com indicação de estado impossível em campanha normal. Diferenciar concessão normal da forçada e reavaliar vitória/derrota após ações.
3. Garantir que comandos não mutem Resources compartilhados nem removam encontros já gerados sem pedido explícito.

**Portão:** comandos reproduzíveis, reversíveis quando cabível e com erro real; desativar debug não altera o pool normal.

### Pool 7 — Aceite cruzado e documentação final  |  prioridade obrigatória  |  etapa G

Executar C01–C18 da especificação, acrescentando: D01–D04 (diretos ausentes em curta/média, mesmo com desfecho ativo, e presentes conforme elegibilidade na completa); I01–I05 (17/44 fora dos sorteios normais de curta/média, Gênio sem desejo de Informação nesses modos, opção preservada na completa e toda Informação concedida restrita ao pool ativo); R01–R04 (preservar 1 Informação fixa e no máximo mais 1 livre por mapa, verificar avanço regular com Informação obtida, vitória da curta em 5 e da média em 10 Informações válidas, conclusão antecipada com duas no mesmo mapa e meta inalterada por Portal/abdução); E01–E08 (A Experiência em curta/média **sem Orchestra** abaixo/acima dos limiares 2/4 e chance fixa de 50%; curta/média **com Orchestra** abaixo/com uma/com ambas as pistas específicas, preservando 50%/75% mesmo que a contagem global atinja 2/4; completa com outcome original; recusa/falha/sucesso, vínculo ao ativador e Encontro único); S01–S03 (autosave nos três gatilhos e recuperação). Registrar resultados por teste e arquivos alterados, inclusive limitações aceitas. Não chamar a etapa concluída só porque os testes existentes de exploração/combate passaram.

## Ambiguidades e decisões ainda pendentes

Estas não devem ser resolvidas por suposição silenciosa. As duas contradições do §4.2 sobre diretos e A Experiência **já foram resolvidas** pela decisão recente e não são perguntas abertas.

| Tema | Dúvida/risco concreto | Momento de resolver |
| --- | --- | --- |
| Limite de campanhas | A especificação trata cinco como proposta, mas também diz “cinco inicialmente”. Confirmar se há limite de UX agora ou catálogo sem teto; se houver, deixá-lo configurável. | Antes do Pool 4. |
| Saves após vitória/derrota | Preservar, arquivar ou excluir? Não apagar automaticamente. Definir também se um slot terminal pode ser carregado apenas para consulta. | Antes dos Pools 4–5. |
| Save em combate e telas transitórias | O texto exige auditar suporte real; não há política de retomada comprovada para um combate/modal parcialmente resolvido. | No desenho do Pool 4. |
| Recompensa de Informação sem candidata | Na completa, em evento forçado por debug ou em outra fonte ainda auditada, decidir a mensagem/outcome quando o pool ativo estiver exaurido. Manter efeitos independentes; não conceder Informação inativa nem sortear parte repetida. | Antes do Pool 3. |
| Vitória durante um outcome composto | A meta deve ser verificada imediatamente após a Informação válida, mas um Evento/Encontro pode ainda ter efeitos e caixas pendentes. Definir se a tela de vitória aguarda a conclusão atômica do outcome sem permitir novas ações, ou interrompe a sequência. | Antes do Pool 2. |
| Derrota com companheiros vivos | “Todos os personagens do grupo” pode incluir aliados, enquanto o Combate atual verifica jogáveis vivos. Precisar se aliados podem manter a campanha após a morte de todos os jogáveis e como preencher vagas. | Antes do Pool 2. |
| Autosave oculto | Especificar se mantém só o último ou múltiplas gerações, como detectar um encerramento forçado e como o restaurado se relaciona a um slot manual sem sobrescrevê-lo. | Antes do Pool 4. |
| Abandono e autosave | A ordem para excluir os três slots é clara; falta decidir se o backup oculto da mesma campanha também deve ser eliminado para impedir restauração após abandono voluntário. | Antes do Pool 4. |
| Progresso não salvo | Para o aviso de Sair, esclarecer se “último salvamento” significa apenas manual ou também o autosave oculto, que é de recuperação e não foi escolhido pelo jogador. | Antes do Pool 5. |
| Nomes dos modos e resumo | A tabela usa **curta / média / completa**, mas o texto do resumo usa **rápida / média / longa** e chama desfecho escolhido de “Informação selecionada”. Uniformizar rótulos sem confundir desfecho com uma parte de Informação. | Antes do Pool 5. |

## Fora do escopo desta leva

Chefes de desfecho, Trena, mapas de chefes, configurações reais de áudio/vídeo e remodelação geral de exploração/combate. A vitória provisória depende **somente** da meta de Informações válidas. Melhorias visuais ou de combate não devem bloquear este trabalho, salvo se impedirem o fluxo de campanha/save.
