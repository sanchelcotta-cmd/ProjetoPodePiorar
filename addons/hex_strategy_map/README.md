# Hexágonos do PPP

Este diretório contém a base do mapa, não o gerador de Eventos/Itens/Encontros.

- `hex_grid.gd`: cria os 40 blocos, calcula vizinhos, distância, alcance e caminhos. Guarda tipo, referência ao Resource e estado de cada bloco. Cada passo custa 1 Stamina.
- `hex_cell.gd`: dados de um bloco individual.
- `hex_renderer.gd`: desenha `hex-ref.png`, recebe cliques e aplica as cores da paleta.
- `hex_palette.gd`: cores de alcance, seleção, revelação e bloco resolvido.
- `map_camera.gd`: câmera opcional preservada por decisão do projeto; a prévia atual não a usa.

A StartZone externa tem três vagas e não conta entre os 40 blocos. O `MapGenerator`, ainda não implementado, deverá escolher o Resource de cada bloco na geração do mapa, respeitando as cotas e a valência. O `HexGrid` apenas recebe e guarda essa escolha.

Para testar as regras do grid com Godot disponível: `godot --headless --path . --script res://scripts/tests/ppp_hex_grid_test.gd`. A cena `res://ppp_map_preview.tscn` é somente uma prévia visual.
