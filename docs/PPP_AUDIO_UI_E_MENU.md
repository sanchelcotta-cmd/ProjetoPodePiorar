# Música do pré-jogo e efeitos de interface — 24/10/2026

## Música do menu

A faixa atual da pasta `SoundX/MUSICA DE MENU` é `turning_pages-cosmic-candlelight-617166.mp3`. Foi copiada, sem modificar o original, para `res://audio/music/pre_game_menu.mp3`. Substitui a faixa que esteve na pasta antes da troca do usuário. Toca em loop no bus `Music` somente quando a cena principal é o menu, a seleção de campanha/personagens ou a confirmação de pré-jogo. Os painéis de carregar, registros, configurações e créditos abertos do menu principal pertencem à cena do menu e preservam a mesma reprodução. A entrada na cena da partida interrompe a faixa. Os mesmos painéis abertos pela pausa pertencem à cena de jogo e **não** ativam a música do menu. Pausa conserva a lógica das rádios de exploração/combate.

O `GameAudio` é o único dono da música e observa a cena principal; painéis não decidem o contexto musical. A seleção e a confirmação não reiniciam a faixa a cada navegação. `ppp_pre_game_menu_music_test.gd` verifica origem, bus, loop, continuidade entre as três cenas e exclusão durante o jogo/pausa.

Na pausa da partida, a rádio escolhida toca com ganho local de **50%** sobre o volume configurado (por exemplo, Música 80% → rádio 40%); o valor salvo não é alterado. Se a pausa for aberta em Combate, a faixa de Combate fica suspensa enquanto a rádio toca; ao voltar, a faixa de Combate retoma e a rádio volta a ficar suspensa. Ao voltar à Exploração, a rádio recupera ganho de 100% sem trocar de estação. O som de hover usa ganho local de 29,25%, independente desse controle de Música.

## SFX da interface

As cópias de `SoundX/UI` estão em `res://audio/sfx/ui/`, com nomes que indicam a função. Todos usam o sub-bus `ClickUI` → `EffectsUI` → `Master`, separado de `Music`. O roteador `GameUISFX` cobre botões dinâmicos, hover e clique na cena. Um som específico prevalece sobre o clique genérico disparado pelo mesmo botão no mesmo frame; o som de equipar prevalece sobre o clique do inventário. Abrir uma caixa de hex é camada separada do clique em seu botão.

| Arquivo no jogo | Aplicação |
| --- | --- |
| `start_game.mp3` | Início efetivo da campanha, após gerar o primeiro mapa |
| `blocked_button.mp3` | Ação bloqueada; ganho local de 68% |
| `hover.mp3` | Passagem do cursor em botão habilitado; ganho local de 29,25% (metade dos 58,5% anteriores) |
| `menu_page.mp3` | Navegação entre telas/abas de menu |
| `confirm.mp3` | Confirmação genérica |
| `equip.mp3` / `unequip.mp3` | Operação de equipamento bem-sucedida |
| `item_reward.mp3` | Abertura de recompensa de item |
| `inventory_click.mp3` | Botões do inventário |
| `epic_craft.mp3` | Criação épica bem-sucedida |
| `outcome_click.mp3` | Botões de escolha e confirmação de Evento |
| `general_click.mp3` | Clique geral; na cena usa pitch 1,13× |
| `hex_open.mp3` | Abertura de bloco e leituras de resultado de Evento |
| `information_found.mp3` | Sinal real de Informação concedida, qualquer origem |
| `info_records_click.mp3` | Botões das Informações e registros de campanha |

O som de Informação vem do sinal `GerenciaJogo.information_granted`, não do simples revelar ou abrir a caixa. Falha de equipar/criar aciona bloqueio, não sucesso. `ppp_ui_sfx_test.gd` verifica disponibilidade das 15 cópias, buses, prioridade, pitch e ganho.

## Limite aceito

Testes automatizados verificam carregamento, contexto e despacho; a equalização perceptiva com a música das rádios e da tela inicial exige audição humana. Verificar licença/crédito dos arquivos antes de uma exportação pública. Sons de Catástrofe e Carreta da Alegria ainda dependem das faixas futuras previstas na documentação da leva.
