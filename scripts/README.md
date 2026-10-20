# Organização dos scripts

Os arquivos `.gd` ficam separados pela função que exercem:

```text
scripts/
├── campaign/             Estado da campanha e das entidades em jogo
├── managers/             Regras que coordenam exploração, blocos e habilidades
├── maps/                 Visualização do mapa na cena
├── resources/            Definições dos dados editáveis no Inspetor
│   ├── encounters/
│   ├── entities/
│   ├── events/
│   ├── information/
│   ├── items/
│   ├── skills/
│   └── status/
└── tests/                Testes executados pelo Godot
```

Os scripts da malha hexagonal e da geração do mapa continuam em
`addons/hex_strategy_map/`, que já é o módulo dedicado a eles. Os arquivos
`.tres` preenchidos no Inspetor continuam em `resources/`; os scripts em
`scripts/resources/` apenas definem seus tipos e campos.

Ao mover um `.gd` no futuro, mova também seu `.gd.uid` e atualize caminhos
`res://` nas cenas e nos Resources que o utilizam.
