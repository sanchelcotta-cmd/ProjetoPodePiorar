# QA/UX — pendências de acessibilidade

Registro de 14/10/2026. A conferência de combate confirmou o fluxo de rolagem,
movimento, seleção de alvo e previsão de dano bruto em testes automatizados.
Já estão disponíveis a conta `Ataque + dado − movimento − distância` ao apontar
para um hostil, o indicador `ALVO n DE m` para corpos sobrepostos e a dica
`Jogue o dado para mover e/ou atacar`. Rolagem baixa não reduz a caminhada
permitida pela Estamina; `APROXIMAR` anda sem consumir o ataque.
Os itens abaixo ficam deliberadamente para uma rodada posterior de UX; **não**
devem ser tratados como funcionalidades já implementadas.

- Navegação integral por teclado: hoje é possível focar os quadros da iniciativa,
  mas a escolha de hexágonos e alvos no mapa ainda depende do mouse. Definir
  cursor de hex, avanço entre hexes/alvos, confirmação e cancelamento por teclado.
- Legibilidade no monitor final: conferir em F5, em resolução efetiva, os textos
  de 10–12 px e ícones de Debuff de 14 px. Testar leitura confortável e alvos de
  clique sem confundir Debuff, equipamento e botões adjacentes. Ajustar escala
  antes de considerar o HUD fechado.
- Fazer um teste com pessoa sem conhecimento prévio das regras para verificar se
  ela descobre o dado, o movimento, a escolha de inimigo e a conta do dano sem
  instruções verbais. O teste automatizado prova o fluxo, não a compreensão.

Qualidade das animações foi excluída desta revisão a pedido do usuário; apenas
o funcionamento e a ordem movimento → ataque foram verificados.

## Câmera do mapa — 24/10/2026

Foi acrescentado zoom discreto em quatro passos (85%, 100%, 115% e 130%) pelo
rolinho ou pela barra segmentada no canto superior. A barra usa divisões brancas,
marcador amarelo e legenda pequena “zoom”. HUD, menus e céu em paralaxe não
escalam junto com o mapa. A câmera ancora a base do Ground e repete a fachada
para os lados, evitando expor bordas no afastamento. Em zoom aproximado, arrastar
na área de cenário/céu, as setas do teclado ou os botões laterais deslocam só
horizontalmente, com sensibilidade moderada e suavização. O deslocamento manual
não obriga o personagem ativo a permanecer visível; duplo clique no cenário/céu
ou no cartão do ativo o reenquadra. Novo turno também traz o ator da vez para
a faixa visível quando necessário. O zoom retorna a 100% e ao pan central ao
selecionar o nível 2.

A implementação de câmera **não** equivale à navegação integral por teclado:
seleção de hexes, alvos e ações continua pendente de mapeamento próprio.
Teste automatizado: `scripts/tests/ppp_map_camera_test.gd` cobre quatro escalas,
limites laterais, repetição da fachada e base do Ground. Ainda cabe revisão
visual/interativa em F5 para sensibilidade de arrasto e composição em resoluções
reais de monitor.
