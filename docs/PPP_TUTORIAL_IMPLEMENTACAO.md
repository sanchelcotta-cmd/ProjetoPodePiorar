# Tutorial interativo do PPP

## Fonte dos textos

Os textos revisados pela autora vêm de `C:\Users\55319\OneDrive\Área de Trabalho\PPP_Tutorial_Textos_Revisado.docx`. O catálogo usado pelo jogo está em `res://resources/tutorial_pages.json`: 92 páginas revisadas, mais uma página de resumo dos atalhos. Falas vazias permanecem vazias; o rosto pode aparecer sem caixa de fala. A página **Atalhos de Teclado** é a segunda guia, tem contador `1 / 1` e rosto sorridente sem fala.

## Acesso e estado

- No Dia 1, o convite inicial aparece uma vez depois que o mapa termina de carregar. O botão lateral abre o tutorial; recolhido, mostra `< T`. O primeiro clique expande e o segundo abre. Ele pode ser arrastado verticalmente. A tecla `T` abre o tutorial durante o Dia 1.
- O convite inicial é uma caixa própria da interface (não um diálogo padrão do Godot), com o rosto à esquerda, texto rosa e as opções **Agora não** e **Ver tutorial**. Ele exige escolha explícita; Esc não o dispensa.
- Enquanto `< T` está disponível, o resumo de Registros ocupa somente a metade superior da lateral e o tutorial ocupa a inferior, sem sobreposição. O resumo recolhido mostra `< R`; ele ainda permite alternar entre 2, 4 e 5 registros recentes. Se o conteúdo crescer, rola dentro da caixa. Depois que o T desaparece, o R pode ser arrastado por toda a lateral direita, dentro das margens da tela.
- `FECHAR TUTORIAL DE VEZ` pede confirmação e remove o convite e o botão lateral do Dia 1. O tutorial continua disponível em **Configurações → Jogabilidade**.
- Convite visto, dispensa, posição e recolhimento do atalho são salvos com a campanha.
- A janela pausa a partida enquanto está aberta e restaura o estado anterior ao fechar, inclusive quando aberta a partir do menu de pausa.

## Interface

A janela usa a paleta ativa do jogo, colunas de guias/páginas/conteúdo e contador local por guia. O corpo emprega a fonte narrativa do jogo, alinhada à esquerda, com separação visual de tópicos e destaque discreto de termos. O rosto é feito com caracteres e usa uma caixa retangular amarela apenas quando há fala revisada para aquela página.

## Verificação

Execute `godot --headless --script res://scripts/tests/ppp_tutorial_test.gd` na raiz do projeto. O teste confere o catálogo, contadores, página silenciosa, abertura/fechamento, atalho lateral, convite, pausa, acesso por Configurações e persistência no save. A prévia visual é gerada por `res://scripts/tests/ppp_tutorial_preview.gd` em `res://artifacts/tutorial_interface_preview.png` e `res://artifacts/tutorial_atalhos_preview.png`.
