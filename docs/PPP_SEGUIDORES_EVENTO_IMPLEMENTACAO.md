# Seguidores dos Eventos 14 e 43 — implementação

- As folhas `bonequinho_idle.png` (16 quadros de 64×64) e `bonequinho_walk.png` (8 quadros de 64×64) foram copiadas da pasta de referência da artista sem alterar os originais. O Bonequinho de Madeira exibe a paleta original.
- O Amigo Imaginário reutiliza os mesmos quadros com um material local: trevo verde convertido em rosa e madeira um pouco mais clara. A recoloração não altera o PNG original, a transparência nem os tempos das animações.
- Um único `BonequinhoAmigo/Sprite` foi acrescentado à cena `orientacao_sprites.tscn`. Sua altura inicial é a mesma da Galinha (64 × 2,140625), com largura proporcional. O visual em jogo lê a escala dessa régua.
- Os dois acompanham seus respectivos donos apenas visualmente, sem ocupar hex lógico, com os pés entre centros de hexes. O deslocamento usa Walk e calcula uma curva de desvio quando uma entidade ou obstáculo está no caminho; ao parar, volta a Idle.
- O Bonequinho surge quando sua proteção é concedida e desaparece ao ser consumida. O Amigo Imaginário surge ao resolver o Evento 14 e desaparece no fim da Rodada correspondente. Mudança de mapa reposiciona os seguidores; morte do dono os oculta.
- A prévia real do mapa está em `artifacts/event_followers_scene.png`.
- Validação: `ppp_event_followers_test.gd`, `ppp_wooden_doll_test.gd`, `ppp_orientacao_sprites_test.gd`, `ppp_event_narrative_binding_test.gd`, `ppp_native_passive_combat_test.gd` e `ppp_save_codec_test.gd` passaram sem avisos de recursos no encerramento. A captura com renderizador também terminou sem avisos.
