extends SceneTree

const GAME := preload("res://teste.tscn")
const PANEL := preload("res://scripts/ui/campaign_debug_panel.gd")
const SERVICE := preload("res://scripts/managers/debug_command_service.gd")
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("DEBUG_FEATURE=", OS.has_feature("debug"))
	var game := GAME.instantiate()
	root.add_child(game)
	var panel := PANEL.new()
	game.add_child(panel)
	var debug := SERVICE.new()
	debug.setup(game)
	_check(not debug.catalog("active").is_empty(), "Catálogo de ativas usa IDs reais.")
	_check(not debug.catalog("passive").is_empty(), "Catálogo de passivas usa IDs reais.")
	_check(not debug.catalog("event").is_empty(), "Catálogo de Eventos usa IDs reais.")
	_check(not debug.catalog("information").is_empty(), "Catálogo de Informações usa IDs reais.")
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	var endings: Array[StringName] = [&"orchestra"]
	var gerencia := game.get_node("GerenciaJogo") as GerenciaJogo
	_check(gerencia.start_new_game(selected, EventCampaignEligibility.Mode.SHORT, endings),
		"Campanha curta inicia para testar elegibilidade.")
	var actor := gerencia.campaign.active_entity_states[0]
	var active := debug.catalog("active")[0]
	var active_id := active["id"] as StringName
	_check(debug.execute("active", active_id, actor).get("success", false),
		"Concessão de ativa passa pelo gestor real.")
	_check(not debug.inspect("active", active_id, actor).get("eligible", true),
		"Ativa já possuída fica bloqueada pelo ID, mesmo no catálogo interno.")
	_check(not debug.execute("active", active_id, actor, 1, true).get("success", false),
		"Forçar não duplica uma Ativa já possuída.")
	_check(debug.undo_last().get("success", false),
		"Concessão de ativa pode ser desfeita.")
	var passive: Dictionary = {}
	for row in debug.catalog("passive"):
		if not (row["resource"] as PassiveSkillData).on_granted_effects.is_empty():
			continue
		passive = row
		break
	if not passive.is_empty():
		_check(debug.execute("passive", passive["id"], actor).get("success", false),
			"Concessão de passiva passa pelo gestor real.")
		_check(debug.undo_last().get("success", false),
			"Concessão de passiva pode ser desfeita.")
	var inactive: Dictionary = {}
	for row in debug.catalog("information"):
		var info := row["resource"] as Informacao
		if not gerencia.campaign.is_information_eligible(info.id, info.tipo):
			inactive = row
			break
	_check(not inactive.is_empty(), "Há Informação de desfecho inativo para teste.")
	if not inactive.is_empty():
		_check(not debug.execute("information", inactive["id"]).get("success", false),
			"Concessão normal recusa Informação inativa.")
		_check(debug.execute("information", inactive["id"], null, 1, true).get("success", false),
			"Concessão forçada é distinta e conta pelo serviço central.")
		_check(not debug.execute("information", inactive["id"], null, 1, true).get("success", false),
			"Nem a força de debug cria Informação duplicada.")
	var round_manager := game.get_node("RoundManager") as RoundManager
	_check(round_manager.start_first_map(), "Mapa de teste é gerado pelo fluxo real.")
	if gerencia.campaign.current_map != null:
		var map := gerencia.campaign.current_map
		var original: Dictionary = {}
		for coord in map.cells:
			var cell := map.get_cell(coord)
			original[coord] = [cell.resource_path, cell.state]
		var chosen_event: Dictionary = {}
		for row in debug.catalog("event"):
			if EventCampaignEligibility.allows_event(row["resource"],
					gerencia.campaign.campaign_mode):
				chosen_event = row
				break
		if not chosen_event.is_empty():
			_check(not debug.inspect("event", chosen_event["id"], actor,
				&"outcome_inexistente").get("forceable", false),
				"Outcome inexistente não se torna forçável.")
			_check(not debug.execute("event", chosen_event["id"], actor, 1,
				true, &"outcome_inexistente").get("success", false),
				"Força de debug recusa outcome fora do Resource.")
			_check(debug.execute("event", chosen_event["id"], actor).get("success", false),
				"Evento virtual é acionado pelo BlockManager real.")
			for coord in original:
				var cell := map.get_cell(coord)
				_check(original[coord] == [cell.resource_path, cell.state],
					"Evento virtual preserva conteúdo e estado do hex.")
			(game.get_node("BlockManager") as BlockManager).finish_event_resolution()
		var encounter := debug.catalog("encounter")[0]
		_check(debug.execute("encounter", encounter["id"], actor, 1, true).get("success", false),
			"Encontro virtual entra pela confirmação real.")
		for coord in original:
			var cell := map.get_cell(coord)
			_check(original[coord] == [cell.resource_path, cell.state],
				"Encontro virtual não substitui o Encontro já gerado.")
		_check((game.get_node("BlockManager") as BlockManager).confirm_encounter(),
			"Confirmar o Encontro virtual inicia o fluxo real de combate.")
		_check((game.get_node("CombatManager") as CombatManager).current_encounter ==
			encounter["resource"], "Combate recebeu o Resource solicitado.")
	ProjectSettings.set_setting("ppp/debug/enabled", false)
	_check(not SERVICE.is_enabled(), "Flag desliga debug sem tocar no pool normal.")
	_check(not gerencia.campaign.grant_information(inactive["resource"], &"debug", true)
		.get("success", false), "Flag desliga também a concessão forçada de domínio.")
	ProjectSettings.set_setting("ppp/debug/enabled", true)
	if OS.has_feature("debug"):
		_check(panel.get_child(0).get_node_or_null("DebugBugButton") != null,
			"O botão de bug existe na camada de interface.")
		_check(panel.get_child_count() > 0, "Painel interno cria a interface.")
	game.queue_free()
	print("DEBUG_PANEL_TEST: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)


func _check(ok: bool, title: String) -> void:
	if not ok:
		failures += 1
		push_error(title)
