# Elementos visuais de UI

Os PNGs de `sprites/ui` usam a sequência `uielementx_00001.png`, etc. O número
identifica a arte, não a tela onde ela aparece. Novas artes entram no próximo
número livre; código e cenas devem referenciar apenas o nome padronizado.

| Arquivo | Origem / uso |
| --- | --- |
| `uielementx_00002.png` | Antiga moldura rosa `inventory_slot_frame`; espaço de item. |
| `uielementx_00003.png` | Antigo separador ciano `pause_menu_cyan_divider`; lateral dos personagens. |
| `uielementx_00004.png` | `Asset 5`; moldura decorativa do retrato no HUD. |
| `uielementx_00005.png` | `Group 5 copy`; corpo da caixa de consequência do bloco. |
| `uielementx_00006.png` | `Asset 11`; faixa do título acima da consequência. |

As artes 00005 e 00006 são recoloridas de ciano para rosa em tempo de execução
por `ui_cyan_to_pink_80.gdshader`. Os arquivos fonte mantêm a cor original;
o shader também limita a opacidade visual a 80%.

As antigas artes 00001, 00007 e 00008 foram removidas: as caixas aplicáveis
agora usam borda simples na mesma cor. A ficha de Debuff deixou de usar a
arte 00002, que continua reservada às caixas de item e à iniciativa.
