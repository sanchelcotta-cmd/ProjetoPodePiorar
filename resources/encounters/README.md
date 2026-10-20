Salve aqui os `.tres` do tipo `EncounterData`, sempre com o prefixo `enc_` no
nome do arquivo. O gerador do mapa lê esta pasta
e suas subpastas, filtra por distrito/horário e coloca o **encontro inteiro** no
hexágono. Os `EntityData` entram na lista `members` de cada encontro, nunca
diretamente no mapa.

`night_only` pertence ao encontro, não à entidade: o gerador compara essa flag
com a Rodada (Manhã, Tarde ou Noite). `unique_encounter` também pertence ao
encontro. Ao gerar um mapa, o gerenciador da campanha deve passar os IDs dos
encontros únicos que **já aconteceram**; um hex apenas gerado e não ativado não
conta como ocorrência. A quantidade mínima/máxima de cada criatura fica nos
`EncounterMemberData` embutidos no `.tres`.
