# Áudio de movimento e ataque — decisões de implementação (revisão 27/10/2026)

## Contrato de cobertura

Todo **movimento executado** e todo **ataque resolvido** recebe SFX, incluindo jogáveis, aliados recrutados, companheiros, hostis humanoides/criaturas/voadores, ataque básico, contra-ataque, ricochete, interceptação do Bumerangue e dano de ativa/passiva. Hover, seleção de alvo, dado, movimento cancelado e habilidade sem golpe não recebem som de ataque. A seleção lê a **instância que agiu**, não o personagem em foco na UI. `GameActionSFX` acompanha os sinais de posição e de resolução, inclusive o deslocamento apenas visual do Doguinho/Gatinho; duas notificações da mesma ação são deduplicadas. Um loop de deslocamento termina ao chegar, morrer, cancelar, trocar de modo, pausar ou sair da cena.

Ordem de resolução: **arma específica equipada → maestria da arma sem corte próprio → maestria efetiva da entidade com grupo A/B/C → punch genérico**. Movimento: **tipo especial (rato/voador/criatura) → perfil jogável → humanoide → passos hostis genéricos**. Um Resource novo sem classificação nunca fica mudo. Grupos A/B/C são escolha de *timbre e peso* do efeito, não modificam estatísticas, chance nem resultado do jogo. O SFX não consome o RNG da campanha.

As faixas usam a folha única `res://audio/sfx/movimentos_de_acao_1.mp3`, sem editar o original em `SoundX/ação`. Os cortes e intensidade relativa estão em `scripts/ui/action_sfx_catalog.gd`; o despachante está em `scripts/ui/game_action_sfx.gd`. O MP3 exportado tem **80,097 s**. A régua numerada da mixagem indica **compassos a 120 BPM**, não segundos: cada compasso 4/4 dura aproximadamente 2 s. Usar seus números como segundos cortava silêncio. O remapeamento do usuário em segundos foi refinado pelos transientes do arquivo importado no Godot: o começo é deslocado poucos centésimos quando a borda anotada ainda contém silêncio. `ppp_audio_segment_peak_test.gd` confere sinal e ganho nos **20 perfis** (19 trechos distintos, pois a lâmina rápida reutiliza a gravação da adaga), inclusive os passos com Armadura de Proteção. Movimento passa por `GeneralSFX` (100% do bus `EffectsUI`), ataques por `CombatSFX` (100%); não passam pelo bus `Music`. O controle **Efeitos e interface** governa ambos; na instalação nova começa em 100%, sem sobrescrever ajustes já persistidos pelo jogador. Ganho local de ataque/movimento nunca é inferior a 1,0; passos comuns tocam a 1,10×, preservando variações mais lentas explicitamente definidas. Um passo curto permanece audível por pelo menos 0,36 s e para ao fim do movimento. A mixagem ainda pede audição humana em equipamento real.

**Reforço dos ataques — 27/10/2026.** Toda voz de ataque recebe 1,5× do ganho que já lhe era atribuído no catálogo, inclusive armas, desarmado, inimigos, contra-ataques, ricochetes e interceptação; passos, UI e música não recebem esse multiplicador. O bus de ataques e o Master recebem limitadores de pico para evitar distorção em golpes fortes ou sobrepostos à rádio. A preferência de volume do jogador permanece intacta. Medição direta dos trechos no Godot confirmou que `punch` e `quick_swoosh` já alcançam seus impactos em 0,077 s e 0,002 s, com picos 0,55/0,50. Por isso, o desarmado continua com seus sons próprios, sem substituir pelo impacto fraco. A lâmina rápida `slashkut` tinha pico apenas 0,27 e foi substituída a pedido do jogador por `quick_blade`, variante acelerada/agudizada do impacto `knife_stab`: este chega ao pico bruto 0,49 logo no início, recebe ganho local 1,25 e o reforço global 1,5. A lâmina grave B continua em `sword_schwing` (pico bruto 0,77). O mesmo recorte-base da adaga aparece em dois perfis sonoros diferentes, mas nenhum ataque de lâmina rápida usa mais o `slashkut`.

**Reação ao golpe e gritos — 27/10/2026.** A folha entregue `hurt_hurt.m4a` foi convertida, sem alterar o original, para `res://audio/sfx/hurt_hurt.wav` (40,04 s, estéreo, 44,1 kHz). `HurtSFXCatalog` vincula trechos específicos aos sete jogáveis e aos 34 tipos de entidade geral, inclusive as três inclusões finais solicitadas. O som da arma começa junto ao ataque. Em corpo a corpo, o quadro 3 da animação (índice 2) libera a reação visual do alvo; o grito começa somente quando o recorte do som de ataque termina. Em ataques à distância, o projétil sai no quadro de soltura da arma e **a chegada real do projétil** dispara simultaneamente reação e grito; o som da arma/corda continua no início do ataque, sem esperar o impacto. Esquiva ou zero dano sem perda da última Vida não acionam reação nem grito. O mesmo protocolo cobre contra-ataque e ricochete; passivas que causam dano fixo tocam um som de ataque e depois um grito por alvo realmente atingido. Na morte, o grito recebe um atraso de 0,12 s e a mesma gravação é repetida discretamente como eco 0,13 s depois; não foi fornecida uma folha de morte separada. Inimigos que ainda são silhuetas não têm sprites de ataque: uma animação provisória em três poses marca o contato, e ataques à distância sem sprite de projétil recebem um traço visual temporário até existirem assets definitivos. `ppp_hit_presentation_test.gd` verifica catálogo, esquiva, espera do quadro 3, voo do projétil, ataque inimigo, ordem dos sons e morte.

## Cortes da folha e função

| Corte | Segundos | Uso principal |
| --- | --- | --- |
| punch / quick_swoosh | 2,30–2,80 / 4,06–4,50 | Desarmado; alternância em jogáveis; sem maestria A/B |
| quick_blade / sword_schwing | 29,25–29,70 (pitch 1,18×) / 10,22–10,50 | Lâmina A/B; quick_blade reutiliza a gravação de knife_stab com tratamento próprio |
| metal_hit / punch_whoosh / awesome_kick | 8,18–8,60 / 18,45–19,10 / 30,20–30,50 | Impacto A/B/C |
| awwow_impact / gun | 16,08–16,50 / 22,00–23,40 | Distância A/B |
| laser_gun / box / knife_stab / cigarette | 12,00–12,50 / 26,36–27,00 / 29,25–29,70 / 32,05–33,10 | Itens específicos |
| electric_zap | 14,11–14,80 | Movimento do Rato-Mutante |
| knife_slice | 20,25–20,80 | Movimento de criaturas, pitch 1,5× |
| wing | 38,18–43,50 | Movimento de voadores; Barata 1,2× |
| steps_hostile | 46,25–50,30 | Humanoides hostis; zumbis 0,8× |
| steps_female / steps_male | 54,31–59,20 / 60,40–66,60 | Jogáveis femininas/masculinos; A Experiência usa masculino |
| steps_armored | 72,00–80,00 | Jogável com Armadura de Proteção, pitch 0,90× |

Passos de jogável com Armadura de Proteção (`ar_00002`) usam o trecho próprio, mais grave (pitch 0,90×), independentemente do gênero. Cortes longos repetem somente enquanto o movimento real/visual continua; cortes curtos não vazam para o segmento seguinte. Pausa e tela sem mapa interrompem as vozes.

## Armas: mapeamento completo atual

| Item | ID | Som |
| --- | --- | --- |
| Adaga de Sombra e Luz | `aa_00001` | knife_stab |
| Arco da Precisão | `aa_00002` | awwow_impact |
| Bastão do Guardião | `aa_00003` | metal_hit |
| Bumerangue Teleguiado | `aa_00004` | gun, também na interceptação bem-sucedida |
| Espada Congelante / Flamejante | `aa_00005` / `aa_00006` | box |
| Martelo de Guerra | `aa_00007` | punch_whoosh |
| Cabo de Vassoura | `aa_00008` | awesome_kick, pitch 0,84× e ganho 1,75× para o golpe atravessar a rádio |
| Chinelo | `aa_00009` | laser_gun |
| Estilingue | `aa_00010` | awwow_impact, escolhido por ser disparo leve à distância |
| Faca / Tesoura | `aa_00011` / `aa_00013` | quick_blade |
| Martelo comum | `aa_00012` | awesome_kick |
| Espada Irada Eletrizante | `aa_00014` | cigarette |

Uma arma futura sem ID na tabela usa sua maestria declarada (A); sem maestria, punch. O ataque com Ricochete emite outro corte na resolução do alvo secundário; não toca por mera existência da passiva.

## Grupos técnicos dos hostis

Maestrias: `0` sem maestria, `1` lâmina, `2` impacto, `3` distância. Em entidade com maestria sorteada, o grupo acompanha o **override efetivo**. Abaixo estão todos os IDs hostis atuais (`en_00003`–`en_00034`); aliados convertidos preservam o perfil de origem.

| Entidade | ID | Maestria → grupo | Decisão sonora |
| --- | --- | --- | --- |
| Aranha Interdimensional | `en_00003` | 2→B, 3→B | Ataque pesado/projétil forte; voo no movimento |
| A Experiência | `en_00004` | 2→B | Impacto pesado; passos masculinos |
| Barata Gigante Voadora | `en_00005` | 0→B | Desarmado agudo; wing 1,2× |
| Bonequinha de Pano | `en_00006` | 1→A | Lâmina rápida; movimento de criatura |
| Cão Infernal | `en_00007` | 1→B | Corte grave; movimento de criatura |
| Capanga Do Mal | `en_00008` | 2→A | Impacto discreto; passos hostis |
| Cobaia Mutante | `en_00009` | 1/2/3→B | Timbre forte para a maestria efetiva |
| Criatura Esquisita de Outra Dimensão | `en_00010` | 1→B | Corte grave; movimento de criatura |
| Cultista Encapuzado | `en_00011` | 3→A | Disparo leve; passos hostis |
| Dama Elemental | `en_00012` | 3→B | Disparo forte; passos hostis |
| Diabretes Flamejantes | `en_00013` | 1→A | Corte rápido; wing por tag voador |
| Esfera Flamejante | `en_00014` | 0→B | Desarmado agudo; movimento de criatura |
| Goblin (lâmina) | `en_00015` | 1→A | Corte rápido |
| Goblin (impacto) | `en_00016` | 2→C | Impacto fraco |
| Goblin (distância) | `en_00017` | 3→A | Disparo leve |
| Guarda-Fantoche | `en_00018` | 2→B | Impacto pesado |
| Homem de Preto | `en_00019` | 1→B, 3→B | Lâmina grave / gun conforme maestria efetiva |
| Mímico 1 / 2 | `en_00020` / `en_00021` | 0→A / 0→B | Desarmado discreto / agudo; criatura |
| Palhaço Assassino | `en_00022` | 1→B | Lâmina grave |
| Pinscher Raivoso | `en_00023` | 1→A | Corte rápido; criatura |
| Planta Carnívora | `en_00024` | 1→B | Lâmina grave; não se move normalmente |
| Pomba Maligna | `en_00025` | 3→A | Disparo leve; wing |
| Raízes Mutantes | `en_00026` | 2→B | Impacto pesado; não se move normalmente |
| Rato-Mutante do Baixo-Centro | `en_00027` | 0→B | Desarmado agudo; electric_zap no movimento |
| Servo Invocador 1 / 2 | `en_00028` / `en_00029` | 3→B / 1→A | Disparo forte / corte rápido |
| Sombra Disforme | `en_00030` | 1→B | Corte grave; wing por tag voador |
| Versão maligna do jogável | `en_00031` | 0/1/2/3→B | Maestria sorteada, sempre grupo B |
| Vilão-Tipicamente Do Mal | `en_00032` | 1/2→B | Lâmina grave / impacto pesado |
| Zumbi Dançarino | `en_00033` | 0→A | Desarmado discreto; passos 0,8× |
| Zumbi que Taca Gosma | `en_00034` | 3→B | Disparo forte; passos 0,8× |

`en_00001` Doguinho e `en_00002` Gatinho são companheiros: deslocamento físico ou apenas visual usa `knife_slice` enquanto dura. Sem arma, o Doguinho usa `sword_schwing` (lâmina média, pitch 1,05×) e o Gatinho `quick_blade` (lâmina aguda, pitch 1,24×). A arma específica equipada continua tendo precedência. Golpe básico, contra-ataque, tentativa sem alcance e ricochete do Gatinho acionam `Attack` no visual por evento de combate resolvido, não por clique/preview. Qualquer inimigo/aliado futuro sem linha usa maestria A, depois punch para ataque, e passos hostis para deslocamento. Nenhum fallback cancela a ação ou omite som.

## Verificação e limites

- `ppp_action_sfx_test.gd`: folha carregada; todas as armas e os 32 hostis atuais classificáveis; fallbacks; movimentação efetiva de exploração e combate; deslocamento visual do Doguinho; ataque, contra-ataque, ricochete, dano passivo e interceptação; roteamento e mudo independentes de Música; parada dos loops; ganho de ataque 1,5× e limitadores presentes.
- `ppp_audio_segment_peak_test.gd`: cada um dos 20 perfis capturados no bus do Godot produz pico ≥0,08 nos primeiros 0,32 s, antes de aplicar ganho local; desarmados e lâminas têm critério mais estrito, pico ≥0,20 e começo perceptível em até 0,18 s. `--scan` e `--scan-late` ajudam a recalibrar se o MP3 for reexportado.
- `ppp_audio_settings_test.gd`: três rádios em cena, seleção, combate provisório, retorno da estação, pausa e volume.
- `ppp_epic_craft_ui_test.gd`: Desequipar e Criar Épico separados no HUD/inventário, inclusive receita dividida entre personagens.
- Regressões executadas: `ppp_combat_turn_test.gd`, `ppp_combat_actives_test.gd`, `ppp_eletrizante_test.gd`, `ppp_ambient_audio_test.gd`, `ppp_pause_menu_test.gd`, `ppp_save_combat_test.gd`, `ppp_ally_animations_test.gd`. Este último foi alinhado ao fluxo atual de arrastar somente após deslocar o cursor; passou sem falhas.

Os testes validam seleção, disparo e duração, mas **não substituem audição humana** para loudness, aspereza de pitch, clipping ou encaixe fino com a animação. Também não concedem licença de redistribuição: conferir origem/créditos dos arquivos antes de exportar publicamente.
