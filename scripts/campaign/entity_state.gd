class_name EntityState
extends RefCounted

## Uma entidade DURANTE a partida. EntityData é o cadastro compartilhado;
## mudar Vida, posição ou controlador aqui nunca altera o arquivo .tres.

signal health_changed(previous: int, current: int)
signal position_changed(previous: Vector2i, current: Vector2i)
signal equipment_changed
signal appearance_changed

enum TurnState {
	AVAILABLE,
	TURNING,
	INACTIVE,
}

enum Controller {
	PLAYER,
	AI,
}

const UNPLACED := Vector2i(-999, -999)

# Identidade desta instância na campanha. Para os três protagonistas, é a
# própria vaga: Playable_1, Playable_2 ou Playable_3. Não é o ID do EntityData.
var instance_id: StringName = &""
var playable_slot_id: StringName = &""
var owner_instance_id: StringName = &""
var data: EntityData
# Evento 26 troca só a identidade apresentada. data continua sendo a ficha
# mecânica original (atributos, Maestrias, Skills e equipamento).
var visual_identity: EntityData


func visual_data() -> EntityData:
	return visual_identity if visual_identity != null else data


func visible_name() -> String:
	var identity := visual_data()
	return identity.display_name if identity != null else ""


func set_visual_identity(identity: EntityData) -> void:
	if visual_identity == identity:
		return
	visual_identity = identity
	appearance_changed.emit()

var position: Vector2i = UNPLACED:
	set(value):
		var previous := position
		position = value
		if previous != value:
			position_changed.emit(previous, value)
# A cor/variante é sorteada uma vez por instância. Não alterar EntityData:
# todos os gatinhos compartilham o mesmo .tres, mas podem ter cores distintas.
var visual_variant_index: int = -1
var current_health: int = 0:
	set(value):
		var previous := current_health
		current_health = value
		if previous != value:
			health_changed.emit(previous, value)
var max_health: int = 0
var attack: int = 0
var max_stamina: int = 0
var stamina_remaining: int = 0
var turn_state: TurnState = TurnState.AVAILABLE
var controller: Controller = Controller.PLAYER
# Água com Açúcar: uma sobrevivência a golpe letal por combate e por instância.
# StringName salva junto à entidade; não altera a ficha compartilhada.
var sugar_lethal_guard_combat_id: StringName = &""
var sugar_attack_adjusted: bool = false
var sugar_enemy_attack_penalty: int = 0
# Estado de criaturas invocadas em Combate. A ficha compartilhada não muda.
var summoned_by_instance_id: StringName = &""
var summoned_can_summon: bool = false
var summoned_acts_immediately: bool = false

# Cada origem conserva sua própria concessão. Uma Skill inata e a mesma Skill
# vinda de um item são duas entradas, podendo acumular conforme a regra do jogo.
var skill_grants: Array[SkillGrantState] = []
# Próximo ataque da Adaga de Sombra e Luz; o save serializa este campo.
var dagger_next_aspect: StringName = &"light"
# Debuffs aplicados nesta instância; nunca são gravados no EntityData.
var debuffs: Array[DebuffInstanceState] = []
# Cada sucesso contra Terror melhora a resistência a uma FONTE do mesmo
# EntityData.id (ou ao ID de um Evento), nunca a todos os causadores.
var terror_resistance_bonus_by_source: Dictionary = {}
# Muda somente quando começa um novo turno desta instância. Trocar a seleção
# antes de agir não cria outro turno nem recarrega habilidades por turno.
var turn_serial: int = 0
var last_exploration_cycle_key: StringName = &""
# Cada concessão de movimento extra guarda a Skill que a criou. Se a mesma
# Skill vier de duas fontes, ambas podem ser usadas independentemente.
var extra_movement_sources: Array[SkillGrantState] = []
# Visão do Futuro: três consultas escolhidas pelo jogador, sem limite de alcance.
# Persistem entre turnos até serem usadas; nunca modificam EntityData.
var future_vision_uses: int = 0
# Premonição: uma consulta por turno, em qualquer hex, até a virada da Rodada.
var premonition_round_index: int = -1
var premonition_used_turn_serial: int = -1
var round_stamina_penalty: int = 0
var round_stamina_penalty_index: int = -1
# O 12 é apenas valor inicial. Mochilas e outros efeitos alteram o bônus,
# sem mudar o cadastro do personagem nem as regras de entrega de itens.
var base_inventory_capacity: int = 12
var inventory_capacity_bonus: int = 0
var inventory_items: Array[InventoryItemState] = []
# Bônus de consumíveis com prazo. Cada entrada conhece a fonte e o turno
# exato em que deve ser retirada; o ItemData continua imutável.
var consumable_timed_modifiers: Array[Dictionary] = []
# Equipados são cópias concretas SEPARADAS do inventário carregado. O caso
# normal é 1 arma, 1 armadura e 1 acessório; efeitos como Terceiro Braço
# podem aumentar a capacidade de um slot sem perder essa separação.
var equipped_weapons: Array[InventoryItemState] = []
var equipped_armors: Array[InventoryItemState] = []
var equipped_accessories: Array[InventoryItemState] = []


func attuned_divine_amulet() -> InventoryItemState:
	if instance_id == &"":
		return null
	for entry in equipped_accessories:
		if entry != null and entry.data != null and entry.data.id == &"ac_00001" \
				and entry.attuned_owner_instance_id == instance_id:
			return entry
	return null


func has_divine_amulet_status_immunity(status_id: StringName) -> bool:
	return status_id in [&"db_00003", &"db_00004", &"db_00005", \
		&"db_00009", &"db_00010"] and attuned_divine_amulet() != null


func is_curse_immune() -> bool:
	return permanent_curse_immunity or attuned_divine_amulet() != null
var unavailable_until_owner_turn_serial: int = 0
# EntityData registra QUAIS Maestrias existem. Bônus numéricos recebidos
# durante a campanha ficam separados até definirmos a fórmula de combate.
var mastery_bonuses: Dictionary = {}
# Uma Maestria pode ser concedida no nível 0; só o bônus numérico não basta
# para saber se a entidade conhece esse tipo de Maestria.
var granted_mastery_types: Dictionary = {}
# Sorteios de Maestria por Encontro afetam apenas esta instância, sem editar
# o EntityData compartilhado (ex.: cada Homem de Preto pode vir diferente).
var encounter_mastery_override: int = EntityData.Mastery.NONE
var equipment_slot_capacity_bonus: Dictionary = {}
var extra_attacks_this_turn: int = 0
# Consumir fora da própria vez prepara o segundo ataque para o próximo turno.
var extra_attacks_next_turn: int = 0
# Proteções recebidas diretamente de Eventos. Guardamos IDs por instância,
# nunca no Resource compartilhado, para que cada personagem tenha seu estado.
var permanent_status_immunities: Array[StringName] = []
var temporary_status_immunities: Array[StringName] = []
var permanent_curse_immunity: bool = false
var ignore_ranged_critical_bonus: bool = false
# Concessão permanente do Duende: no próprio turno de Exploração, um único
# movimento ainda ativa o bloco escolhido, mas não custa Estamina nem usa alcance.
var unlimited_exploration_movement: bool = false
# Aparência/ausência de eventos são apenas desta instância, nunca do EntityData.
var temporary_appearance: StringName = &""
var temporarily_absent_from_map: bool = false


func get_animation_variant() -> SpriteSheetAnimationData:
	if data == null or data.animation_variants.is_empty():
		return null
	if visual_variant_index < 0 or visual_variant_index >= data.animation_variants.size():
		return null
	return data.animation_variants[visual_variant_index]


func has_mastery(mastery: EntityData.Mastery) -> bool:
	if mastery == EntityData.Mastery.NONE:
		return false
	if encounter_mastery_override != EntityData.Mastery.NONE and data != null \
			and mastery in data.maestrias:
		return mastery == encounter_mastery_override
	return (data != null and mastery in data.maestrias) \
		or int(granted_mastery_types.get(mastery, 0)) > 0 \
		or int(mastery_bonuses.get(mastery, 0)) > 0


func get_mastery_level(mastery: EntityData.Mastery) -> int:
	# Estar listado no EntityData começa em nível 0; não soma 1 implícito.
	var level := int(mastery_bonuses.get(mastery, 0))
	# Equipamento não ensina uma Maestria. Seu bônus só vale para quem já
	# nasceu com o tipo correspondente; assim uma arma nunca muda o tipo do
	# Universitário e retirar o item desfaz o bônus automaticamente.
	if mastery == EntityData.Mastery.NONE or data == null \
			or mastery not in data.maestrias:
		return level
	for entries in [equipped_weapons, equipped_armors, equipped_accessories]:
		for entry in entries:
			if entry != null and entry.data != null \
					and entry.data.mastery_granted == mastery:
				level += entry.data.mastery_bonus
	return level


func equipment_slot_capacity(slot_id: StringName) -> int:
	return maxi(0, 1 + int(equipment_slot_capacity_bonus.get(slot_id, 0)))


func inventory_capacity() -> int:
	return maxi(0, base_inventory_capacity + inventory_capacity_bonus)


func inventory_used_space() -> int:
	var used := 0
	for entry in inventory_items:
		if entry != null and entry.data != null:
			used += entry.data.inventory_space
	return used


func equipped_in_slot(slot: ItemData.EquipmentSlot) -> Array[InventoryItemState]:
	match slot:
		ItemData.EquipmentSlot.WEAPON: return equipped_weapons
		ItemData.EquipmentSlot.ARMOR: return equipped_armors
		ItemData.EquipmentSlot.ACCESSORY: return equipped_accessories
	return []


func primary_equipped(slot: ItemData.EquipmentSlot) -> InventoryItemState:
	var entries := equipped_in_slot(slot)
	return entries[0] if not entries.is_empty() else null


func apply_round_stamina_penalty(amount: int, round_index: int) -> bool:
	if amount <= 0:
		return false
	if round_stamina_penalty_index != round_index:
		clear_round_stamina_penalty()
		round_stamina_penalty_index = round_index
	var actual := mini(amount, max_stamina)
	max_stamina -= actual
	round_stamina_penalty += actual
	stamina_remaining = mini(stamina_remaining, max_stamina)
	return true


func clear_round_stamina_penalty() -> void:
	max_stamina += round_stamina_penalty
	round_stamina_penalty = 0
	round_stamina_penalty_index = -1


## Chamado uma vez, DEPOIS que o jogador escolhe o personagem para a vaga.
## Equipamentos, inventário e efeitos temporários terão estado próprio quando
## seus sistemas forem implementados; não duplicamos Resources aqui à força.
static func from_playable_selection(
		selected_data: EntityData,
		slot_id: StringName,
		start_position: Vector2i,
) -> EntityState:
	var state := EntityState.new()
	state.instance_id = slot_id
	state.playable_slot_id = slot_id
	state.data = selected_data
	state.position = start_position
	state.max_health = selected_data.vida_base
	state.current_health = state.max_health
	state.attack = selected_data.ataque_base
	state.max_stamina = selected_data.stamina_base
	state.stamina_remaining = state.max_stamina
	state.turn_state = TurnState.AVAILABLE
	state.controller = Controller.PLAYER
	return state


## Instância hostil temporária de um Encontro. O Resource continua intacto.
static func from_encounter_member(enemy_data: EntityData, encounter_id: StringName,
		serial: int, spawn_coord: Vector2i) -> EntityState:
	var state := EntityState.new()
	state.instance_id = StringName("%s:enemy:%d" % [encounter_id, serial])
	state.data = enemy_data
	state.position = spawn_coord
	state.max_health = enemy_data.vida_base
	state.current_health = state.max_health
	state.attack = enemy_data.ataque_base
	state.max_stamina = enemy_data.stamina_base
	state.stamina_remaining = state.max_stamina
	state.controller = Controller.AI
	return state
