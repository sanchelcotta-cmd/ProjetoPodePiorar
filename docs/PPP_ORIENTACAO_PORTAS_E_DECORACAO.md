# Orientação de portas e pré-preparo da decoração

## Cena de orientação

`res://scenes/visuals/orientacao_portas_backgrounds.tscn` reúne as sete fachadas atualmente sorteáveis (`Subúrbio` 0001–0003, `Baixo-Centro` 0001–0002 e `Centro` 0001–0002). Cada fachada traz a PNG original e um nó `Portas` com retângulos rosa `Porta_XX`. As marcações podem ser adicionadas, movidas ou removidas pelo usuário; as PNGs originais não são modificadas.

Para ajustar uma entrada no Godot: abra a cena no editor 2D, expanda `Fachadas > [fachada] > Portas`, selecione `Porta_XX` e arraste ou redimensione o retângulo com o mouse. `Ctrl+D` duplica uma área; `Delete` a remove. Salve a cena após editar. Cada contorno deve cobrir a porta e o corredor livre até a calçada, com a folga necessária à passagem dos personagens. Os nomes e os caminhos da arte estão gravados em cada fachada, para que as áreas continuem associadas à imagem correta mesmo quando o mapa sortear ou repetir uma fachada.

Imagem e marcações compartilham a mesma posição e escala de prévia (0,5×); as coordenadas dos retângulos representam pixels da PNG original. Não altere apenas a escala de `Imagem` ou apenas a de `Portas`. O teste `res://scripts/tests/ppp_background_door_orientation_test.gd` confere as sete artes, o alinhamento e se os retângulos estão dentro das respectivas imagens.

**Uso atual:** o gerador lê as áreas da cena de orientação e as transforma conforme a fachada sorteada, sua escala e as cópias laterais. Uma fachada nova sem áreas marcadas não recebe decoração do grupo A até que suas portas sejam indicadas.

## Decoração implementada no mapa

Todas as decorações são ordenadas visualmente pela base, sem Y-sort interno dos sprites: detalhes das casas ao fundo, grupo A na frente, árvores do grupo B na frente do A e postes do grupo C na frente das árvores. Personagens continuam intercalados pela posição dos próprios pés no mundo.

**Prioridade das regras de posição:** (1) nenhum objeto A/B/C pode obstruir os hexes; (2) o grupo A jamais ocupa as áreas de porta marcadas; (3) árvores B preferem evitar portas, mas podem ficar diante delas se não existir outra posição segura; (4) postes C não têm restrição de porta, apenas de hex e dos marcadores de meio-fio. Se uma regra de quantidade ou distribuição conflitar com uma restrição superior, a vaga é descartada, sem empurrar o objeto para a parede ou para cima de um hex. Novas fachadas precisam ter as portas indicadas na cena de orientação antes de receber elementos A — inclusive a lixeira obrigatória do Centro.

### Cenário distante — entre céu e fachadas

As PNGs de `res://sprites/background/camadas_cenario/` são sorteadas pela semente do mapa, sem depender da quantidade de fachadas existentes: `bairro-suburbio` no Subúrbio, `baixo-centro` no Baixo-Centro, `centro-historico` no Centro e `intermediaria` elegível no Subúrbio/Baixo-Centro. A camada é apenas visual, atrás das fachadas e à frente do paralaxe; não participa de colisões, portas ou hexes.

A base do PNG procura uma faixa inteiramente coberta pela parte inferior das fachadas. Caso uma arte futura não tenha nenhuma faixa opaca contínua, a borda fica escondida atrás do chão e o Godot avisa que essa fachada precisa de revisão. Cópias espelhadas nas laterais cobrem inclusive o zoom de 85% e o deslocamento máximo da câmera, sem distorcer a arte. Uma amostragem da área de céu **realmente livre entre/acima dos telhados** limita a escala para preservar pelo menos 40% desse céu na câmera padrão; deslocamento horizontal e altura variam pela semente, e o enquadramento se adapta ao resize sem trocar o arquivo sorteado. Quando o paralaxe ativo é `cinzento_*`, um filtro próprio torna essa camada mais cinza que as fachadas, restaurando as cores ao sair do céu cinzento. O teste `res://scripts/tests/ppp_scenic_backdrop_test.gd` cobre catálogo, sorteio estável, céu, base, zoom/pan e filtro em todas as fachadas atuais; `res://scripts/tests/ppp_scenic_backdrop_preview.gd` gera amostras por distrito.

### Grupo A — junto às fachadas

- De zero a cinco elementos decorativos por mapa, admitindo repetição e respeitando o espaçamento de cada tipo; não cobrir hexes nem entradas. O par balde + banquinho conta como um conjunto. A restrição de portas é **obrigatória para o grupo A**; não foi aplicada aos postes do grupo C.
- Balde-banquito só aparece ao lado do banquinho branco; o banquinho pode aparecer sozinho.
- O banquinho branco foi ampliado para o dobro da escala anterior, tanto avulso quanto no conjunto; o balde manteve a escala. A largura reservada pelo conjunto e a distância entre os dois desenhos acompanham o novo tamanho.
- Lixeiras não misturam modelos no mesmo mapa e aparecem em uma ou duas unidades quando selecionadas.
- No **Centro**, há sempre ao menos uma lixeira brasileira tradicional ou lixeira-latão. Havendo duas, são do mesmo modelo. O banquinho branco, sozinho ou no conjunto com balde, é menos provável nesse distrito.
- Saco de lixo preto pode ficar ao lado da lixeira-latão ou simples.
- Vaso espada-de-são-jorge é livre e mais frequente no Subúrbio.

### Grupo B — meio da calçada

- Opcional, de zero a quatro árvores por mapa, com no máximo quatro elementos do grupo B ao todo (incluindo eventual vaso). A árvore fica **plantada na calçada**, não na parede. O contato inferior opaco do pé/tronco não pode ocupar o contorno de um hex; se não houver vão seguro, aquela vaga fica vazia.
- Uma árvore usa uma das laterais. Duas usam uma lateral cada. Três ocupam lateral esquerda, centro e lateral direita. Quando houver uma quarta, seu centro visual fica na borda direita da câmera, de modo que parte da copa possa sair da tela; ela também depende de base livre. Cada posição procura apenas o vão seguro da própria faixa, sem aglomerar árvores em outra.
- A vaga central é reservada à quaresmeira e, futuramente, a espécies de proporção igual ou menor explicitamente sinalizadas. Ipê, jabuticabeira e jerivá ficam nas laterais. Ipê, jabuticabeira e jerivá estão 20% maiores que antes; quaresmeira permanece no tamanho anterior.
- Ipê-amarelo mais provável no Centro; quaresmeira mais provável no Subúrbio; espécies com chances iguais no Baixo-Centro; jerivá muito mais raro no conjunto.
- Quando houver jabuticabeiras, colocar uma de cada lado, fora do alcance dos hexes. As árvores **preferem** ficar longe das portas, mas podem ficar diante delas se só ali houver um vão seguro; isso não flexibiliza a regra do grupo A.
- O vaso espada-de-são-jorge pode aparecer ao lado de uma árvore comum, sem anomalia e sem sobrepor hexes.
- O sorteio das posições e espécies usa uma sequência independente da fachada e das anomalias. Forçar uma anomalia ou adicionar um vaso não reorganiza as árvores já sorteadas.

### Grupo C — postes próximos ao meio-fio

- Sempre três ou quatro postes por mapa, espaçados conforme os marcadores editáveis `PostSpawnAnchors/ThreePosts` e `FourPosts` na cena `res://scenes/game/campaign_game.tscn`. Um mapa usa um único modelo de poste: histórico **ou** tradicional. Cada marcador ajusta a base horizontalmente até o vão seguro mais próximo, sem cobrir o contorno dos hexes.
- Histórico apenas no Baixo-Centro/Centro. Tradicional obrigatório no Subúrbio e também possível nos outros distritos.
- Não encostar nos hexes. Personagens desviam dos objetos B/C, passando à frente ou atrás conforme a posição; nunca os atravessam.
- À noite, cada modelo emite luz a partir da posição própria de sua lâmpada: halo arredondado e facho cônico largo, mais intenso perto do topo e perdendo força até a faixa amarela da rua. Há reflexo ciano sutil no halo normal e sombra dinâmica dos personagens sob os fachos. Cada poste tem 5% de chance de luz verde neon, independentemente das anomalias; moscas em torno da lâmpada surgem ocasionalmente.

### Sombras de contato — prévia para aprovação

Personagens e demais entidades usam a mesma sombra radial oval anterior, agora com 20% menos opacidade; a sombra projetada sob os postes acompanha essa redução. Decorações A/B/C têm sombra de contato com 30% menos opacidade que a dos personagens já ajustada. O centro da oval fica ligeiramente acima da base real do sprite, avançando alguns pixels para trás e para a frente, sem bordas retas. As sombras dos objetos ficaram cerca de 10% mais largas; nas árvores, a largura acompanha a copa visível, inclusive quando animada pela anomalia. Postes C projetam essa sombra somente de manhã e à tarde; à noite permanecem seus efeitos de luz e a sombra dinâmica de quem passa sob o facho. O cenário distante atrás das fachadas não tem contato com o chão e não recebe sombra. As capturas de prévia são `res://artifacts/decoration_three_posts.png` e `res://artifacts/decoration_four_posts.png`; a aparência final aguarda aprovação.

### Anomalias

- A partir do segundo dia: chance inicial de 5% de uma anomalia a cada mapa gerado, aumentando cinco pontos percentuais após cada mapa sem ocorrência; após ocorrer, volta a 5%.
- Em campanhas longas/completas, a partir da 12ª Informação: piso de 50%, crescendo dez pontos percentuais a cada mapa sem ocorrência e retornando a 50% após ocorrer.
- A partir da 16ª Informação: chance fixa de 90%.
- Há no máximo uma anomalia por mapa. As quatro anomalias de objetos concorrem com duas anomalias de fundo; se nenhuma base elegível tiver surgido, o gerador substitui um objeto possível. Ao forçar outra pelo depurador, a anterior é substituída.
- `anomalia_lixo_pé`: substitui o saco de lixo preto. Na primeira chegada aos hexes centrais, o saco normal some e a anomalia corre até a borda e desaparece.
- `anomalia_duende_lixeira`: substitui a lixeira brasileira tradicional; costuma ficar no primeiro quadro e ocasionalmente anima.
- `anomalia_arvore_de_fogo`: quando sorteada, **todas** as árvores presentes viram árvores de fogo. Cada uma emite halo circular lilás/roxo mais intenso e pequenas brasas roxas/rosadas que sobem em curva e desaparecem na borda da luz.
- `anomalia_mao_poste`: usa a folha revisada `res://sprites/decoration/anomalia_poste_olho_2.0_1x.png`. Após o primeiro movimento de um personagem, **todos** os postes do mapa trocam juntos para a forma da mão/olho. Cada um permanece majoritariamente no primeiro quadro, com movimentos ocasionais em intervalos menores que 60 segundos; a iluminação do poste é preservada.
- `anomalia_galo_fundo`: surge atrás das fachadas e atravessa o cenário alternando sentidos; ganha peso extra após Transformação Galiforme. A animação exibe apenas a parte superior de cada quadro, ocultando os pés no próprio recorte do atlas, inclusive quando a fachada deixa um vão.
- `anomalia_lixo_ovni`: cruza o céu em zigue-zague, reaparecendo em menos de um minuto; ganha peso extra à noite. O sprite está a 65% do tamanho anterior e tem brilho difuso, sem bordas quadradas. Suas luzes coloridas pulsam suavemente da mesma forma com ou sem a opção de conforto visual.
- No painel interno de depuração, **Forçar · Debug** pode gerar qualquer uma dessas anomalias já no dia 1; a trava do dia 2 vale somente para o sorteio normal. Forçar outra anomalia substitui a anterior, sem permitir várias simultâneas no mesmo mapa. Se não houver posição segura para a base solicitada, o comando falha e restaura a anomalia anterior sem deixar sorteio pendente. O poste forçado usa marcadores validados contra hexes; a anomalia da lixeira preserva um único modelo no mapa, e a do saco não remove a lixeira obrigatória do Centro.

### Validação da distribuição

`res://scripts/tests/ppp_decoration_runtime_test.gd` percorre 48 sementes de mapa para conferir o limite de quatro elementos, os pés das árvores livres dos hexes, a quarta árvore possível e o fogo em todas as árvores. Também testa 40 sementes em cada uma das duas fachadas atuais do Centro: ao menos uma lixeira tradicional/latão, modelo único quando há duas e nenhuma decoração A sobre porta. O mesmo teste confere a escala do banquinho e do balde no conjunto e força as seis anomalias no dia 1. `res://scripts/tests/ppp_debug_panel_test.gd` abre as categorias Anomalias/Tempo e usa o próprio painel para forçar uma anomalia no dia 1, cobrindo o erro anterior de conversão entre `Array` comum e `Array[Dictionary]`. `res://scripts/tests/ppp_decoration_lighting_preview.gd` captura o mapa renderizado com três árvores, incluindo a posição central, e variantes de luz à noite e à tarde.

`res://scripts/tests/ppp_decoration_runtime_test.gd` também verifica que a troca para o novo atlas alcança todos os postes no primeiro movimento e que o recorte do galo remove a área dos pés.

### Transformação Galiforme — referência visual

`res://scenes/visuals/orientacao_sprites.tscn` contém um quadro Idle da galinha em `Transformacoes/Galinha/Sprite`. A escala salva da **altura** é aplicada igualmente à largura; no editor, alterar a altura faz a largura acompanhar para evitar distorção. O mapa lê só esse valor da cena, sem instanciá-la para cada personagem. Durante o efeito, o sprite humano é substituído pelas folhas Idle, Walk, Attack e Hurt da galinha; o ataque corpo a corpo e o de distância usam o mesmo gesto. Com arma de distância equipada, o terceiro quadro lança um ovo branco pixelado em arco e o impacto só é anunciado ao alcançar o alvo. Ao expirar o efeito, a animação e a escala originais retornam. Testes: `res://scripts/tests/ppp_orientacao_sprites_test.gd`, `res://scripts/tests/ppp_galiform_visual_test.gd` e `res://scripts/tests/ppp_random_events_timed_test.gd`.

Na referência visual enviada em 28/10/2026, as duas linhas amarelas delimitam **uma faixa vertical estreita no centro do mapa**. A primeira chegada a um hex cujo **centro** cai entre essas linhas dispara a corrida de `anomalia_lixo_pé`, independentemente da fileira, do zoom ou do deslocamento da câmera; não depende dos pixels fixos da tela. O usuário confirmou que a faixa se refere ao saco de lixo com pés, não ao duende da lixeira.

## Limite geométrico identificado na revisão visual

O contorno clicável dos hexes ocupa toda a faixa intermediária do meio-fio nos marcadores centrais. A posição vertical exata da linha roxa enviada em 28/10/2026 não permite encaixar todos os postes sem sobreposição: a varredura de 120 px para ambos os lados não encontrou vão nos marcadores centrais. A implementação conserva os marcadores horizontais aproximados e posiciona as bases na faixa livre imediatamente acima da primeira fileira de hexes. As capturas reais com três e quatro postes estão em `res://artifacts/decoration_three_posts.png` e `res://artifacts/decoration_four_posts.png`. Essa diferença visual deve ser confirmada pelo usuário; não reduzir a margem dos hexes silenciosamente.
