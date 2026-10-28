# Playtest comparativo — campanha média e saque pós-combate

Data: 22/10/2026. Escopo final solicitado: comparar as duas campanhas até o mesmo número de combates do primeiro teste, sem exigir conclusão das 10 Informações. As campanhas foram configuradas no modo **Média**, com meta de **10 Informações** e desfechos Khainokata + Orchestra.

## Método

- Mesmo trio: Pedreiro, Mãe e Jornalista; mesma semente, equipamentos iniciais, rota e política de decisões.
- O controlador automatizado escolheu apenas entre hexes que a interface disponibilizaria para ativação. Não leu conteúdo de hex oculto. Preferiu o destino disponível mais próximo, aceitou a primeira escolha viável em eventos, usou cura quando a Vida caiu abaixo de 50% e, em combate, atacou o hostil vivo de menor Vida ou se aproximou dele.
- Sem saque: o combate fez o sorteio normal, mas o controlador recusou cada item. Com saque: guardou os itens oferecidos. Assim, a rolagem ocorreu nos dois lados; a diferença experimental foi possuir ou não a recompensa.
- O marco comparável foi **o início do 8º encontro**. Os sete anteriores estavam concluídos. Nenhum mapa foi pulado nas execuções usadas nesta comparação.
- Este é um teste automatizado de progressão e dificuldade, **não** uma sessão humana de usabilidade. O controlador não equipou automaticamente o acessório recebido e não escolheu táticas avançadas ou habilidades de revelação. Portanto, pode subestimar o valor do saque.

## Resultado no mesmo marco

| Métrica | Sem saque | Com saque |
| --- | ---: | ---: |
| Combates concluídos / iniciados | 7 / 8 | 7 / 8 |
| Vitórias | 7 | 7 |
| Informações | 1/10 | 1/10 |
| Mapas gerados | 2 | 2 |
| Saques oferecidos | 4 | 4 |
| Saques guardados | 0 | 4 |
| Consumíveis usados pelo controlador | 3 | 3 |
| Vida no marco — Jornalista | 35/35 | 35/35 |
| Vida no marco — Pedreiro | 25/32 | 25/32 |
| Vida no marco — Mãe | 17/35 | 17/35 |

A sequência dos oito encontros foi igual nos dois lados: Zumbis Dançarinos, Sombra Disforme, São tipo Goblins, Pomba Maligna, Barata Gigante Voadora, Pomba Maligna, Criatura Esquisita de Outra Dimensão e novamente Zumbis Dançarinos, todos no Subúrbio. A primeira Informação surgiu depois dos seis primeiros encontros.

Os quatro saques da execução com recompensa foram: **Relógio de Bolso**, **Combo Família**, **Pão com Mortadela** e **Prato Feito Perfeito**. O relógio dá chance de turno extra quando equipado; Combo Família recupera 15 de Vida do grupo, Pão com Mortadela recupera 3 de Vida e dá +1 de Estamina por um turno, e Prato Feito Perfeito recupera toda a Vida de um usuário. Nenhum desses saques havia produzido diferença nos valores de Vida ou no número de consumíveis usados até o marco observado.

## Leitura honesta de dificuldade

O começo foi **intenso em encontros por progresso de Informação**: seis encontros antes da primeira pista nesta rota cega. Ainda assim, o trio ganhou os sete combates completos e chegou vivo ao segundo mapa. Isso não demonstra facilidade geral: a Mãe estava em 17/35 de Vida, três consumíveis já tinham sido gastos e a amostra cobre só 1/10 da meta.

Até o início do oitavo combate, a recompensa pós-combate **não alterou a dificuldade observada**. Ela criou uma reserva potencialmente poderosa para os próximos combates, especialmente as duas curas grandes, mas este recorte não mede se essa reserva transforma derrotas em vitórias mais adiante. O uso não automático do Relógio de Bolso também reduz o benefício mensurado.

**Conclusão de balanceamento:** não há evidência suficiente para afirmar que o saque tornou a campanha média fácil ou que sua ausência a tornou injusta. Há evidência de pressão inicial por encontros e de que o saque oferece fôlego futuro. A avaliação da campanha inteira até 10 Informações continua em aberto.

## Limites e descarte

Uma execução intermediária com saque usou duas passagens excepcionais de mapa sem Informação. Ela mudou a sequência de encontros e foi **descartada** da comparação. Os números da tabela vêm das execuções sem esse atalho. Um falso positivo inicial do controlador durante a animação de ataque do aliado também foi corrigido antes de estabelecer o marco; não foi tratado como defeito do combate.

Para concluir o balanceamento da campanha Média, o próximo teste precisará alcançar 10 Informações ou uma derrota real com ambas as regras de saque, idealmente em mais de uma semente e com equipagem/uso de recompensas semelhante ao de um jogador humano.
