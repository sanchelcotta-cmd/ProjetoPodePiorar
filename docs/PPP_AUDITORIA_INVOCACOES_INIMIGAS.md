# Auditoria de invocações inimigas — 20/10/2026

Escopo: todos os `EntityData` em `resources/entities/entities_general` e todos os `SkillEffectData.EffectType.SUMMON_ENTITY` conectados a eles. A invocação cria **instâncias de EntityData**, nunca a composição inteira de um `EncounterData`. Regra padrão: **convidado não convida**; uma exceção futura precisa marcar explicitamente `summoned_can_summon = true` no efeito.

| Skill ID | Quem invoca | Quando / chance | Entidade por acionamento | Limite adicional |
| --- | --- | --- | --- | --- |
| `enemy_active_006` | Dama Elemental | abertura, 50% | 1 Planta Carnívora **ou** Raízes Mutantes | uma tentativa por Dama; convidado não invoca |
| `enemy_active_007` | Planta Carnívora | abertura, 50% | 1 Dama Elemental **ou** Raízes Mutantes | uma tentativa por Planta; convidado não invoca |
| `enemy_active_008` | Raízes Mutantes | abertura, 50% | 1 Dama Elemental **ou** Planta Carnívora | uma tentativa por Raízes; convidado não invoca |
| `enemy_active_009` | Palhaço Assassino | turnos próprios 3, 6, 9…, 50% | 1 Guarda-Fantoche | convidado não invoca |
| `enemy_active_010` | Guarda-Fantoche | turnos próprios 3, 6, 9…, 50% | 1 Palhaço Assassino | convidado não invoca |
| `enemy_active_011` | Servo Invocador | turnos próprios 3, 6, 9…, 100% | 1 Sombra Disforme | até 3 Sombras vivas por Servo; convidado não invoca |
| `enemy_active_012` | Vilão Tipicamente do Mal | abertura e início de cada turno próprio, 50% | 1 Capanga do Mal | até 3 Capangas vivos por Vilão; convidado não invoca |
| `enemy_active_013` | Horda de Zumbis que Tacam Gosma | começo do ciclo 3, 100%, se ao menos um sobreviveu | **2 Zumbis Dançarinos no total** | uma única leva compartilhada por Encontro, não por zumbi; convidados não invocam |

As três invocações elementais são limitadas também no executor: a tag estável `invocacao_inicio` impõe no máximo uma instância, mesmo se um Resource futuro aumentar `amount`. O grupo de abertura é iterado como cópia para não processar convidados recém-criados na mesma abertura. A vedação de cadeia existe tanto no fluxo automático quanto no executor direto.

`resources/skills/actives/invocacao_3.tres` é um Resource genérico antigo, sem ID de Skill, sem `entity_id` e sem ligação com `EntityData`; **não está ativo**. Se vier a ser usado, precisará de ID/alvo válidos e de nova auditoria.

Verificação: `scripts/tests/ppp_enemy_summon_audit_test.gd` passou. Ele inventaria os oito IDs e abre Encontros reais das três criaturas elementais, da horda zumbi e dos quatro outros invocadores para verificar número de instâncias, momento e ausência de cadeia. Também passaram `ppp_combat_actives_test.gd`, `ppp_combat_turn_test.gd`, `ppp_combat_entry_test.gd` e `ppp_combat_event_chain_test.gd`. Avisos de limpeza de Resources ao encerrar Godot não foram investigados nesta tarefa, conforme decisão anterior.
