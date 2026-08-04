### Projeto Pode Piorar ###
> Você saiu de casa procurando respostas.
> Encontrou alienígenas, cultistas, zumbis dançarinos, pombas homicidas, uma velha fofoqueira armada com um cabo de vassoura e um homem de terno que parece saber exatamente quantas informações você já descobriu.

## Bem-vindo ao Projeto Pode Piorar
Projeto Pode Piorar é um digital board game single-player que combina investigação, exploração procedural, gerenciamento de recursos e combate tático em um universo onde humor nonsense, ficção científica, lendas urbanas e horror cósmico coexistem.
Ao longo da campanha, o jogador precisa equilibrar risco, planejamento e adaptação para sobreviver em uma cidade onde praticamente qualquer esquina pode esconder uma nova conspiração.

## Objetivo
Projeto Pode Piorar é um projeto pessoal desenvolvido por um único autor.

A ideia nasceu durante a pandemia como um board game de papel e, com o tempo, evoluiu para um jogo digital. Este repositório registra essa transição e reúne tanto o desenvolvimento do jogo quanto meu aprendizado como desenvolvedor.

Além do objetivo de transformar essa ideia em realidade, o projeto também funciona como um laboratório para estudar arquitetura de jogos, organização de sistemas, inteligência artificial, geração procedural, design de mecânicas e boas práticas de desenvolvimento utilizando a Godot Engine.

Se, durante esse caminho, alguém também se divertir explorando um universo cheio de conspirações, humor nonsense e situações completamente improváveis, então o projeto terá cumprido seu papel.


## Principais Características
* Investigue quatro grandes conspirações através da coleta de 20 Informações únicas, capazes de alterar permanentemente o desenvolvimento da campanha.
* Forme um grupo com 3 dos 7 personagens jogáveis, cada um com atributos, habilidades e funções distintas, incentivando diferentes composições, sinergias e estilos de jogo.
* Explore mapas gerados proceduralmente, oferecendo novas rotas, desafios e oportunidades a cada campanha.
* Encare 75 eventos aleatórios, distribuídos entre resultados positivos, negativos e ambíguos, utilizando um sistema de balanceamento para manter a imprevisibilidade sem comprometer a justiça da partida.
* Derrote mais de 30 inimigos únicos, cada um com habilidades, comportamentos e padrões próprios de combate.
* Enfrente uma IA baseada em prioridades e tomada de decisão contextual, permitindo que diferentes situações produzam comportamentos diferentes dos inimigos.
* Administre condições persistentes como Doença, Terror, Tristeza e Maldições, que afetam combate, exploração e outros sistemas da campanha.
* Desenvolva equipamentos através de um sistema de crafting simples, combinando itens comuns para criar versões épicas com mecânicas inéditas.
* Progrida através do conhecimento. Descobrir a verdade é tão importante quanto vencer combates: novas Informações desbloqueiam chefes, modificam a campanha e alteram a presença de facções inimigas.

## Princípios de Design
O Projeto Pode Piorar foi desenvolvido com uma premissa central: os sistemas devem interagir entre si.
Informações influenciam eventos. Eventos afetam a exploração. Debuffs modificam a economia da campanha. Chefes derrotados alteram a geração de inimigos. A composição do grupo redefine a forma como o mapa é explorado.
Em vez de construir mecânicas independentes, o objetivo é criar um conjunto de sistemas capazes de produzir consequências emergentes, incentivando planejamento, adaptação e experimentação a cada nova campanha.
Da mesma forma, a aleatoriedade nunca deve substituir estratégia. O inesperado faz parte da experiência, mas o resultado da partida deve refletir principalmente as decisões tomadas pelo jogador.

## Tecnologias
* Godot Engine
* GDScript
* Git
* GitHub

## Estado do Desenvolvimento
Atualmente o projeto encontra-se na fase de implementação da infraestrutura principal.
Sistemas em desenvolvimento em Resources:
* Entidades
* Eventos
* Informações
* Itens
* Habilidades ativas e passivas
* Efeitos e condições
* Sistema de combate
* Inteligência Artificial
* Geração procedural de mapas
