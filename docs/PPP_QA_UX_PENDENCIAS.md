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
