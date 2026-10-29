class_name CampaignSaveRepository
extends RefCounted

## Três saves MANUAIS por campanha; o número de campanhas não tem teto.
## Novo Jogo gera campaign_id, mas não cria arquivo nem reserva slot.
const FORMAT_VERSION := 1
const SLOT_COUNT := 3
const DEFAULT_ROOT := "user://campaign_saves"
const MAX_SAVE_BYTES := 32 * 1024 * 1024
const AUTO_SLOT_NUMBER := 0

const RUNTIME_FIELDS := {
	"ExplorationManager": ["current_actor", "cycle_number", "_turn_committed",
		"_has_moved_this_turn", "_awaiting_block", "_reopened_extra_movement"],
	"PlayerSkillManager": ["_pending_actor", "_pending_coord", "_pending_options",
		"_last_started_serial_by_instance"],
	"BlockManager": ["_phase", "_grid", "_coord", "_content",
		"_original_block_type", "_actor", "_origin_mode", "_combat_from_event",
		"_combat_encounter", "_combat_announced", "_event_announced",
		"last_information_grant_result"],
	"EventExecutor": ["_rng", "_prepared", "_pending_result", "_shared_rolls",
		"_recent_dice_results", "_event_combat_waiting", "_chained_event_parent",
		"_random_target_groups", "_narrative_key", "_narrative_bindings",
		"_queued_world_transition", "_queued_day_advance", "_final_center_arrival"],
	"CombatManager": ["enemies", "initiative_order", "current_encounter",
		"pending_conclusion", "current_actor", "combat_cycle", "action_mode",
		"_combat_serial", "_rng", "_combat_id", "_turn_index", "_turn_die",
		"_steps_moved", "_attacks_used", "_turn_moved", "_retaliation_by_enemy",
		"_exploration_snapshot", "_combat_turns_by_id",
		"_encounter_automatic_skill_uses", "_combat_interaction_enabled",
		"_promotion_cleanup_pending", "_pending_trap", "_pending_attack_coord",
		"_timed_attack_penalties", "_damage_guards", "_guard_reductions",
		"_guard_expiry_turn_by_id", "_next_attack_bonuses",
		"_mother_attack_bonuses", "_encounter_reveal_sources",
		"_selected_skill_grant", "_previous_skill_targets",
		"_pending_recruitment", "_recruitment_feedback_pending",
		"_attack_animation_pending", "_solo_actor", "_solo_restored",
		"_pending_event_reward", "_event_reward_claimed",
		"_loot_participant_ids", "_loot_entry_max_health", "_loot_damage_taken",
		"_loot_rolled", "_loot_items", "_loot_resolved_count",
		"_loot_resolutions"],
	"CatastropheManager": ["_rng", "_extra_actors", "_observed", "_expiring"],
	"Gnomes2Manager": ["active", "_round_index", "_information_chance",
		"_rng", "positions", "color_paths"],
	"Gnomes3Manager": ["_rng", "_spawned_map", "_generated_paths",
		"_activated_count"],
	"SkillManager": ["_status_triggers_in_progress"],
	"CampaignJournalRecorder": ["_last_combat_id", "_last_encounter_name",
		"_encounter_activator"],
}
const OPTIONAL_RUNTIME_FIELDS := {"CombatManager": ["_loot_participant_ids",
	"_loot_entry_max_health", "_loot_damage_taken", "_loot_rolled",
	"_loot_items", "_loot_resolved_count", "_loot_resolutions"],
	"EventExecutor": ["_final_center_arrival"]}

var storage_root := DEFAULT_ROOT
var validation_error := ""
var _terminal_recorded_instances: Dictionary = {}


func _init(root_path: String = DEFAULT_ROOT) -> void:
	storage_root = root_path


func capture(campaign: CampaignState, scene_root: Node = null) -> Dictionary:
	if campaign == null or campaign.campaign_status == CampaignState.CampaignStatus.NOT_STARTED:
		return {"success": false, "reason": "Não há campanha iniciada."}
	if not _valid_id(campaign.campaign_id):
		return {"success": false, "reason": "ID da campanha inválido."}
	var runtime := {}
	if scene_root != null:
		var readiness := _scene_save_readiness(scene_root)
		if not readiness.get("success", false):
			return readiness
		for node_name in RUNTIME_FIELDS:
			var node := scene_root.get_node_or_null(NodePath(node_name))
			if node == null:
				return {"success": false, "reason": "Controlador ausente: %s" % node_name}
			var fields := {}
			for name in RUNTIME_FIELDS[node_name]:
				fields[name] = node.get(name)
			runtime[node_name] = fields
		var skill_manager := scene_root.get_node_or_null("SkillManager") as SkillManager
		if skill_manager != null:
			runtime["skill_inventory_pending"] = skill_manager.inventory_manager._pending_deliveries
		var executor := scene_root.get_node_or_null("EventExecutor") as EventExecutor
		if executor != null:
			runtime["event_inventory_pending"] = executor._inventory_manager._pending_deliveries
	var codec := CampaignSaveCodec.new()
	var graph := codec.encode({"campaign": campaign, "runtime": runtime,
		"next_item_order": InventoryItemState._next_acquisition_order})
	if not codec.error.is_empty():
		return {"success": false, "reason": codec.error}
	return {"success": true, "graph": graph}


func save_campaign(campaign: CampaignState, slot_number: int,
		scene_root: Node = null, overwrite_confirmed: bool = false) -> Dictionary:
	if campaign != null and is_archived(campaign.campaign_id):
		return {"success": false, "reason": "Campanha arquivada: os slots são somente para consulta."}
	if slot_number < 1 or slot_number > SLOT_COUNT:
		return {"success": false, "reason": "Escolha um dos três slots manuais."}
	if not storage_root.begins_with("user://"):
		return {"success": false, "reason": "Raiz de saves não permitida."}
	var snapshot := capture(campaign, scene_root)
	if not snapshot.get("success", false):
		return snapshot
	var destination := _slot_path(campaign.campaign_id, slot_number)
	var previous := {}
	var occupied := FileAccess.file_exists(destination) \
		or FileAccess.file_exists(destination + ".bak")
	if occupied:
		if not overwrite_confirmed:
			return {"success": false, "reason": "Confirme a substituição deste slot."}
		previous = _read_validated_slot(destination, campaign.campaign_id, slot_number)
		if not previous.get("success", false):
			return {"success": false,
				"reason": "O slot principal está inválido; o backup será preservado."}
	var slot_id := str(previous.get("slot_id", _new_id()))
	var payload_json := JSON.stringify(snapshot["graph"])
	var preview := _preview_from_campaign(campaign)
	var preview_json := JSON.stringify(preview)
	var now := Time.get_datetime_string_from_system()
	var envelope := {
		"kind": "manual",
		"format_version": FORMAT_VERSION,
		"schema_version": campaign.schema_version,
		"campaign_id": campaign.campaign_id,
		"slot_id": slot_id,
		"slot_number": slot_number,
		"created_at": str(previous.get("created_at", now)),
		"saved_at": now,
		"payload_sha256": payload_json.sha256_text(),
		"payload_json": payload_json,
		"preview_json": preview_json,
		"preview_sha256": preview_json.sha256_text(),
	}
	var written := _write_verified(destination, envelope, not previous.is_empty())
	if not written.get("success", false):
		return written
	return {"success": true, "campaign_id": campaign.campaign_id,
		"slot_id": slot_id, "slot_number": slot_number}


## Um arquivo próprio por campanha; nunca participa da contagem de slots.
func save_autosave(campaign: CampaignState, scene_root: Node,
		trigger: StringName, active_seconds: float) -> Dictionary:
	if campaign != null and is_archived(campaign.campaign_id):
		return {"success": false, "reason": "Campanha arquivada."}
	if not storage_root.begins_with("user://") or not _valid_id(campaign.campaign_id):
		return {"success": false, "reason": "Identidade da campanha inválida."}
	var snapshot := capture(campaign, scene_root)
	if not snapshot.get("success", false):
		return snapshot
	var destination := _autosave_path(campaign.campaign_id)
	var previous := _read_validated_autosave(destination, campaign.campaign_id)
	var slot_id := str(previous.get("slot_id", _new_id()))
	var payload_json := JSON.stringify(snapshot["graph"])
	var preview := _preview_from_campaign(campaign)
	var preview_json := JSON.stringify(preview)
	var now := Time.get_datetime_string_from_system()
	var envelope := {
		"kind": "autosave", "format_version": FORMAT_VERSION,
		"schema_version": campaign.schema_version,
		"campaign_id": campaign.campaign_id, "slot_id": slot_id,
		"slot_number": AUTO_SLOT_NUMBER,
		"created_at": str(previous.get("created_at", now)),
		"saved_at": now, "trigger": str(trigger),
		"active_seconds": active_seconds,
		"payload_sha256": payload_json.sha256_text(),
		"payload_json": payload_json,
		"preview_json": preview_json,
		"preview_sha256": preview_json.sha256_text(),
	}
	var written := _write_verified(destination, envelope,
		previous.get("success", false))
	if not written.get("success", false):
		return written
	return {"success": true, "campaign_id": campaign.campaign_id,
		"saved_at": now, "trigger": trigger}


func load_campaign(campaign_id: String, slot_number: int,
		scene_root: Node = null) -> Dictionary:
	if not _valid_id(campaign_id) or slot_number < 1 or slot_number > SLOT_COUNT:
		return {"success": false, "reason": "Campanha ou slot inválido."}
	if is_archived(campaign_id):
		return {"success": false, "reason": "Esta campanha está arquivada para consulta apenas."}
	var destination := _slot_path(campaign_id, slot_number)
	var envelope := _read_validated_slot(destination, campaign_id, slot_number)
	var used_backup := false
	if not envelope.get("success", false):
		envelope = _read_validated_slot(destination + ".bak", campaign_id, slot_number)
		used_backup = true
	if not envelope.get("success", false):
		return {"success": false, "reason": "Save incompatível ou corrompido."}
	var codec := CampaignSaveCodec.new()
	var decoded: Variant = codec.decode(envelope["graph"])
	if not codec.error.is_empty() or not decoded is Dictionary:
		return {"success": false, "reason": "Estado inválido: " + codec.error}
	var restored := decoded["campaign"] as CampaignState
	if restored == null or restored.campaign_id != campaign_id \
			or restored.schema_version != CampaignState.SCHEMA_VERSION:
		return {"success": false, "reason": "Esquema da campanha incompatível."}
	if scene_root != null:
		var applied := apply_to_scene(scene_root, decoded)
		if not applied.get("success", false):
			return applied
		restored = (scene_root.get_node("GerenciaJogo") as GerenciaJogo).campaign
	InventoryItemState._next_acquisition_order = int(decoded.get("next_item_order", 0))
	_terminal_recorded_instances.erase(restored.get_instance_id())
	return {"success": true, "campaign": restored,
		"slot_id": envelope["slot_id"], "used_backup": used_backup,
		"runtime": decoded.get("runtime", {})}


func load_autosave(campaign_id: String, scene_root: Node = null) -> Dictionary:
	if not _valid_id(campaign_id):
		return {"success": false, "reason": "Campanha inválida."}
	if is_archived(campaign_id):
		return {"success": false, "reason": "Esta campanha está arquivada para consulta apenas."}
	var destination := _autosave_path(campaign_id)
	var envelope := _read_validated_autosave(destination, campaign_id)
	var used_backup := false
	if not envelope.get("success", false):
		envelope = _read_validated_autosave(destination + ".bak", campaign_id)
		used_backup = true
	if not envelope.get("success", false):
		return {"success": false, "reason": "Backup incompatível ou corrompido."}
	var codec := CampaignSaveCodec.new()
	var decoded: Variant = codec.decode(envelope["graph"])
	if not codec.error.is_empty() or not decoded is Dictionary:
		return {"success": false, "reason": "Backup inválido: " + codec.error}
	var restored := decoded["campaign"] as CampaignState
	if restored == null or restored.campaign_id != campaign_id \
			or restored.schema_version != CampaignState.SCHEMA_VERSION:
		return {"success": false, "reason": "Esquema do backup incompatível."}
	if scene_root != null:
		var applied := apply_to_scene(scene_root, decoded)
		if not applied.get("success", false):
			return applied
		restored = (scene_root.get_node("GerenciaJogo") as GerenciaJogo).campaign
	InventoryItemState._next_acquisition_order = int(decoded.get("next_item_order", 0))
	_terminal_recorded_instances.erase(restored.get_instance_id())
	return {"success": true, "campaign": restored,
		"saved_at": envelope["saved_at"], "trigger": envelope.get("trigger", ""),
		"used_backup": used_backup}


## A marca só existe enquanto uma sessão pode ter sido interrompida.
func mark_session_open(campaign_id: String) -> bool:
	if not _valid_id(campaign_id) or not storage_root.begins_with("user://"):
		return false
	var folder := _campaign_folder(campaign_id)
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return false
	var file := FileAccess.open(_session_path(campaign_id), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(campaign_id)
	file.flush()
	file.close()
	return true


func mark_session_closed(campaign_id: String) -> bool:
	if not _valid_id(campaign_id) or not storage_root.begins_with("user://"):
		return false
	var marker := _session_path(campaign_id)
	return not FileAccess.file_exists(marker) \
		or DirAccess.remove_absolute(ProjectSettings.globalize_path(marker)) == OK


## Só a saída voluntária e confirmada descarta este progresso recuperável.
func discard_autosave(campaign_id: String) -> bool:
	if not _valid_id(campaign_id) or not storage_root.begins_with("user://"):
		return false
	for path in [_autosave_path(campaign_id), _autosave_path(campaign_id) + ".bak",
			_session_path(campaign_id)]:
		if FileAccess.file_exists(path) \
				and DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
			return false
	return true


func list_recoverable_autosaves() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for campaign_id in list_campaign_ids():
		var recovery := inspect_recoverable_autosave(campaign_id)
		if not recovery.is_empty():
			result.append(recovery)
	return result


func list_campaigns() -> Array[Dictionary]:
	var catalog: Array[Dictionary] = []
	for campaign_id in list_campaign_ids():
		var entry := inspect_campaign(campaign_id)
		if not entry.is_empty():
			catalog.append(entry)
	return catalog


## A enumeração é barata; a validação completa fica por campanha para a UI
## poder ceder um quadro entre entradas sem abrir mão da verificação de saves.
func list_campaign_ids() -> Array[String]:
	var ids: Array[String] = []
	for folder_name in list_all_campaign_ids():
		if not is_archived(folder_name):
			ids.append(folder_name)
	return ids


func list_all_campaign_ids() -> Array[String]:
	var ids: Array[String] = []
	var directory := DirAccess.open(storage_root)
	if directory == null:
		return ids
	for folder_name in directory.get_directories():
		if _valid_id(folder_name):
			ids.append(folder_name)
	return ids


func inspect_recoverable_autosave(campaign_id: String) -> Dictionary:
	if not _valid_id(campaign_id) or is_archived(campaign_id) or not FileAccess.file_exists(
			_session_path(campaign_id)):
		return {}
	var envelope := _read_catalog_autosave(_autosave_path(campaign_id), campaign_id)
	var backup_only := false
	if not envelope.get("success", false):
		envelope = _read_catalog_autosave(_autosave_path(campaign_id) + ".bak",
			campaign_id)
		backup_only = true
	if not envelope.get("success", false):
		return {}
	return {"campaign_id": campaign_id,
		"saved_at": str(envelope.get("saved_at", "")),
		"trigger": str(envelope.get("trigger", "")),
		"backup_only": backup_only,
		"preview": _catalog_preview(envelope)}


func inspect_campaign(campaign_id: String) -> Dictionary:
	if not _valid_id(campaign_id) or is_archived(campaign_id):
		return {}
	var slots: Array[Dictionary] = []
	for slot_number in range(1, SLOT_COUNT + 1):
		var path := _slot_path(campaign_id, slot_number)
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
			continue
		var envelope := _read_catalog_slot(path, campaign_id, slot_number)
		var backup_only := false
		if not envelope.get("success", false):
			envelope = _read_catalog_slot(path + ".bak", campaign_id, slot_number)
			backup_only = true
		slots.append({"slot_number": slot_number,
			"slot_id": str(envelope.get("slot_id", "")),
			"saved_at": str(envelope.get("saved_at", "")),
			"valid": envelope.get("success", false),
			"backup_only": backup_only,
			"preview": _catalog_preview(envelope)
				if envelope.get("success", false) else {}})
	# A lista precisa apenas da quantidade: o conteúdo de cada livro só é
	# decodificado quando o jogador abre aquele registro específico.
	var line_ids := list_terminal_line_ids(campaign_id)
	if slots.is_empty() and line_ids.is_empty():
		return {}
	return {"campaign_id": campaign_id, "slots": slots,
		"terminal_count": line_ids.size()}


## Compara o estado jogável atual ao slot manual mais recente. O backup
## automático nunca conta como save escolhido pelo jogador.
func compare_latest_manual_save(campaign: CampaignState,
		scene_root: Node) -> Dictionary:
	if campaign == null or not _valid_id(campaign.campaign_id):
		return {"has_manual_save": false, "has_changes": true}
	var latest: Dictionary = {}
	for slot_number in range(1, SLOT_COUNT + 1):
		var path := _slot_path(campaign.campaign_id, slot_number)
		var envelope := _read_validated_slot(path, campaign.campaign_id, slot_number)
		if not envelope.get("success", false):
			envelope = _read_validated_slot(path + ".bak", campaign.campaign_id,
				slot_number)
		if envelope.get("success", false) and (latest.is_empty() \
				or str(envelope.get("saved_at", "")) > str(latest.get("saved_at", ""))):
			latest = envelope
	if latest.is_empty():
		return {"has_manual_save": false, "has_changes": true}
	var current := capture(campaign, scene_root)
	if not current.get("success", false):
		return {"has_manual_save": true, "has_changes": true,
			"comparison_error": str(current.get("reason", "Estado indisponível."))}
	return {"has_manual_save": true,
		"has_changes": JSON.stringify(current["graph"]).sha256_text() \
			!= str(latest.get("payload_sha256", "")),
		"saved_at": str(latest.get("saved_at", "")),
		"slot_number": int(latest.get("slot_number", 0))}


func _preview_from_campaign(campaign: CampaignState) -> Dictionary:
	var characters: Array[String] = []
	for actor in campaign.active_entity_states:
		if actor != null and actor.current_health > 0 and actor.data != null:
			characters.append(actor.visible_name())
	var latest_entry := "Nenhuma ação registrada."
	if not campaign.journal_entries.is_empty():
		latest_entry = str(campaign.journal_entries.back().get("text", latest_entry))
	var ending_ids: Array[String] = []
	for ending_id in campaign.active_ending_ids:
		ending_ids.append(str(ending_id))
	return {
		"mode": campaign.campaign_mode,
		"difficulty": campaign.difficulty,
		"pending_difficulty": campaign.pending_difficulty,
		"ending_ids": ending_ids,
		"day": campaign.day,
		"period": campaign.round_period,
		"district": str(campaign.district),
		"information_count": campaign.obtained_information_order.size(),
		"information_goal": campaign.information_goal(),
		"characters": characters,
		"latest_entry": latest_entry,
		"status": campaign.campaign_status,
	}


## Cada conclusão é uma linha independente. Nunca sobrescrever um final ao
## carregar um slot antigo e alcançar outro resultado, mesmo na mesma campanha.
func record_terminal_line(campaign: CampaignState) -> Dictionary:
	if campaign == null or not campaign.is_terminal() \
			or not _valid_id(campaign.campaign_id) or is_archived(campaign.campaign_id):
		return {"success": false, "reason": "Campanha terminal inválida ou arquivada."}
	var instance_key := campaign.get_instance_id()
	if _terminal_recorded_instances.has(instance_key):
		var prior: Dictionary = _terminal_recorded_instances[instance_key]
		if prior.get("campaign_id") == campaign.campaign_id:
			return {"success": true, "campaign_id": campaign.campaign_id,
				"line_id": prior["line_id"], "already_recorded": true}
	var line_id := _new_id()
	var destination := _terminal_path(campaign.campaign_id, line_id)
	var entries: Array = []
	for entry in campaign.journal_entries:
		entries.append(entry.duplicate(true))
	var payload := {"campaign_id": campaign.campaign_id,
		"status": campaign.campaign_status, "mode": campaign.campaign_mode,
		"difficulty": campaign.difficulty,
		"journal_schema_version": 2,
		"ending_ids": campaign.active_ending_ids.map(func(id: StringName) -> String:
			return str(id)), "entries": entries}
	var payload_json := JSON.stringify(payload)
	var envelope := {"kind": "terminal_line", "format_version": FORMAT_VERSION,
		"line_id": line_id, "created_at": Time.get_datetime_string_from_system(),
		"payload_sha256": payload_json.sha256_text(), "payload_json": payload_json}
	var folder := destination.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return {"success": false, "reason": "Não foi possível criar o arquivo de desfechos."}
	var temporary := destination + ".tmp-" + _new_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "Não foi possível gravar o desfecho."}
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	var verified := _read_terminal_line(temporary, campaign.campaign_id)
	if not verified.get("success", false) or FileAccess.file_exists(destination):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"success": false, "reason": "O desfecho não passou na validação."}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(destination)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"success": false, "reason": "O desfecho não foi publicado."}
	# Índice pequeno e descartável: nunca fazer a biblioteca decodificar todas
	# as entries só para mostrar um cartão. Falha do índice não invalida o livro.
	var header := {"campaign_id": campaign.campaign_id, "line_id": line_id,
		"created_at": str(envelope["created_at"]),
		"status": campaign.campaign_status, "mode": campaign.campaign_mode,
		"journal_schema_version": 2, "ending_ids": payload["ending_ids"]}
	var indexed := _write_terminal_header(campaign.campaign_id, line_id, header)
	_terminal_recorded_instances[instance_key] = {"campaign_id": campaign.campaign_id,
		"line_id": line_id}
	return {"success": true, "campaign_id": campaign.campaign_id,
		"line_id": line_id, "index_written": indexed}


func list_terminal_lines(campaign_id: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for line_id in list_terminal_line_ids(campaign_id):
		var line := inspect_terminal_line(campaign_id, line_id)
		if not line.is_empty():
			lines.append(line)
	lines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("created_at", "")) < str(b.get("created_at", "")))
	return lines


func list_terminal_line_ids(campaign_id: String) -> Array[String]:
	var ids: Array[String] = []
	if not _valid_id(campaign_id):
		return ids
	var directory := DirAccess.open(_terminal_folder(campaign_id))
	if directory == null:
		return ids
	for filename in directory.get_files():
		if not filename.ends_with(".pppline"):
			continue
		var line_id := filename.trim_suffix(".pppline")
		if _valid_id(line_id):
			ids.append(line_id)
	return ids


func inspect_terminal_line(campaign_id: String, line_id: String) -> Dictionary:
	if not _valid_id(campaign_id) or not _valid_id(line_id):
		return {}
	var line := _read_terminal_line(_terminal_path(campaign_id, line_id), campaign_id)
	return line if line.get("success", false) and line.get("line_id") == line_id else {}


## Só metadados de um arquivo terminal. Nenhuma entry é lida/decodificada.
## Livros antigos sem índice aparecem com identificação genérica e são
## validados integralmente apenas quando o jogador escolhe aquele livro.
func inspect_terminal_line_header(campaign_id: String, line_id: String) -> Dictionary:
	if not _valid_id(campaign_id) or not _valid_id(line_id) or not FileAccess.file_exists(
			_terminal_path(campaign_id, line_id)):
		return {}
	var path := _terminal_meta_path(campaign_id, line_id)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null and file.get_length() > 0 and file.get_length() < 8192:
			var parser := JSON.new()
			var parsed: Variant = null
			if parser.parse(file.get_as_text()) == OK:
				parsed = parser.data
			file.close()
			if parsed is Dictionary and parsed.get("header_json") is String:
				var header_json := str(parsed["header_json"])
				var header_parser := JSON.new()
				var header: Variant = null
				if header_parser.parse(header_json) == OK:
					header = header_parser.data
				if header is Dictionary and str(header.get("campaign_id", "")) == campaign_id \
						and str(header.get("line_id", "")) == line_id \
						and header_json.sha256_text() == str(parsed.get("sha256", "")):
					return header
		elif file != null:
			file.close()
	var modified := FileAccess.get_modified_time(_terminal_path(campaign_id, line_id))
	return {"campaign_id": campaign_id, "line_id": line_id,
		"created_at": Time.get_datetime_string_from_unix_time(modified)
			if modified > 0 else "", "mode": -1, "status": -1,
		"ending_ids": [], "journal_schema_version": 1, "legacy": true}


func _write_terminal_header(campaign_id: String, line_id: String,
		header: Dictionary) -> bool:
	var destination := _terminal_meta_path(campaign_id, line_id)
	var temporary := destination + ".tmp-" + _new_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var header_json := JSON.stringify(header)
	file.store_string(JSON.stringify({"header_json": header_json,
		"sha256": header_json.sha256_text()}))
	file.flush()
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(destination)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	return true


func inspect_archive_marker(campaign_id: String) -> Dictionary:
	if not is_archived(campaign_id):
		return {}
	var marker := FileAccess.open(_archive_path(campaign_id), FileAccess.READ)
	if marker == null:
		return {}
	var value: Variant = JSON.parse_string(marker.get_as_text())
	marker.close()
	if not value is Dictionary or value.get("campaign_id") != campaign_id:
		return {}
	return {"campaign_id": campaign_id,
		"archived_at": str(value.get("archived_at", ""))}


func is_archived(campaign_id: String) -> bool:
	return _valid_id(campaign_id) and FileAccess.file_exists(_archive_path(campaign_id))


func archive_campaign(campaign_id: String) -> Dictionary:
	if not _valid_id(campaign_id) or is_archived(campaign_id):
		return {"success": false, "reason": "Campanha inválida ou já arquivada."}
	var lines := list_terminal_lines(campaign_id)
	if lines.is_empty():
		return {"success": false, "reason": "Somente campanhas concluídas podem ser arquivadas."}
	var marker := _archive_path(campaign_id)
	var temp := marker + ".tmp-" + _new_id()
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "Não foi possível arquivar a campanha."}
	file.store_string(JSON.stringify({"campaign_id": campaign_id,
		"archived_at": Time.get_datetime_string_from_system(),
		"line_count": lines.size()}))
	file.flush()
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),
			ProjectSettings.globalize_path(marker)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return {"success": false, "reason": "Não foi possível publicar o arquivo."}
	return {"success": true}


func list_archived_campaigns() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(storage_root)
	if directory == null:
		return result
	for campaign_id in directory.get_directories():
		if is_archived(campaign_id):
			var archived_at := ""
			var marker := FileAccess.open(_archive_path(campaign_id), FileAccess.READ)
			if marker != null:
				var value: Variant = JSON.parse_string(marker.get_as_text())
				marker.close()
				if value is Dictionary and value.get("campaign_id") == campaign_id:
					archived_at = str(value.get("archived_at", ""))
			result.append({"campaign_id": campaign_id,
				"archived_at": archived_at,
				"lines": list_terminal_lines(campaign_id)})
	return result


## O resumo é uma projeção descartável do livro integral, nunca a fonte dos
## fatos. A curadoria editorial do livro arquivado continuará configurável.
func summarize_terminal_line(line: Dictionary) -> Array[Dictionary]:
	var rounds: Array[Dictionary] = []
	var by_round := {}
	var relevant := ["information", "encounter_started", "combat_finished",
		"event_outcome", "event_prevented", "item_collected", "combat_loot", "craft_item",
		"playable_death", "campaign_terminal", "recruitment"]
	for value in line.get("entries", []):
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		if str(entry.get("action_id", "")) not in relevant:
			continue
		var key := str(entry.get("round_index", -1))
		if not by_round.has(key):
			var round := {"round_index": int(entry.get("round_index", -1)),
				"day": int(entry.get("day", 1)),
				"period": int(entry.get("period", 0)),
				"district": str(entry.get("district", "")), "entries": []}
			by_round[key] = round
			rounds.append(round)
		(by_round[key]["entries"] as Array).append(entry)
	return rounds


## Projeção provisória para o livro arquivado. Só resume fatos presentes no
## registro imutável; não recompõe outcomes a partir dos Resources atuais.
func summarize_archive_line(line: Dictionary) -> Array[Dictionary]:
	var rounds: Array[Dictionary] = []
	var by_round: Dictionary = {}
	var active_encounter := ""
	var active_encounter_round_key := ""
	var encounter_damage := 0
	var encounter_deaths := 0
	for value in line.get("entries", []):
		if not value is Dictionary:
			continue
		var entry := value as Dictionary
		var key := str(entry.get("round_index", -1))
		if not by_round.has(key):
			var summary := {"round_index": int(entry.get("round_index", -1)),
				"day": int(entry.get("day", 1)),
				"period": int(entry.get("period", 0)),
				"district": str(entry.get("district", "")),
				"events": [], "encounter": {}, "group_damage": 0,
				"collected": [], "crafted": [], "deaths": [], "recruits": [],
				"damaged_skill_without_amount": false}
			by_round[key] = summary
			rounds.append(summary)
		var current: Dictionary = by_round[key]
		var action := str(entry.get("action_id", ""))
		var segments: Array = entry.get("segments", [])
		var references: Dictionary = entry.get("references", {})
		match action:
			"event_outcome":
				_archive_append_unique(current["events"], _archive_segment(segments, "event", str(entry.get("text", ""))))
			"encounter_started":
				active_encounter = _archive_segment(segments, "negative", str(entry.get("text", "")))
				active_encounter_round_key = key
				encounter_damage = 0
				encounter_deaths = 0
			"attack", "counterattack":
				var damage := maxi(0, int(references.get("damage", 0)))
				if _archive_first_tone(segments) == "hostile":
					if not active_encounter.is_empty():
						encounter_damage += damage
				else:
					current["group_damage"] = int(current["group_damage"]) + damage
			"skill":
				if _archive_first_tone(segments) != "hostile":
					if references.has("damage"):
						current["group_damage"] = int(current["group_damage"]) \
							+ maxi(0, int(references["damage"]))
					else:
						current["damaged_skill_without_amount"] = true
			"item_collected", "combat_loot":
				_archive_append_unique(current["collected"], _archive_segment(segments, "item", str(entry.get("text", ""))))
			"craft_item":
				_archive_append_unique(current["crafted"], _archive_segment(segments, "item", str(entry.get("text", ""))))
			"playable_death":
				_archive_append_unique(current["deaths"], _archive_segment(segments, "actor", str(entry.get("text", ""))))
				if not active_encounter.is_empty():
					encounter_deaths += 1
			"recruitment":
				_archive_append_unique(current["recruits"], _archive_last_segment(segments, "actor", str(entry.get("text", ""))))
			"combat_finished":
				if not active_encounter.is_empty():
					_archive_consider_encounter(by_round[active_encounter_round_key],
						active_encounter, encounter_damage, encounter_deaths)
				active_encounter = ""
				active_encounter_round_key = ""
	if not active_encounter.is_empty() and by_round.has(active_encounter_round_key):
		_archive_consider_encounter(by_round[active_encounter_round_key],
			active_encounter, encounter_damage, encounter_deaths)
	return rounds


func _archive_consider_encounter(summary: Dictionary, name: String,
		damage: int, deaths: int) -> void:
	var previous: Dictionary = summary["encounter"]
	if previous.is_empty() or deaths > int(previous.get("deaths", 0)) \
			or (deaths == int(previous.get("deaths", 0)) \
			and damage > int(previous.get("damage_taken", 0))):
		summary["encounter"] = {"name": name,
			"damage_taken": damage, "deaths": deaths}


func _archive_segment(segments: Array, tone: String, fallback: String) -> String:
	for value in segments:
		if value is Dictionary and str(value.get("tone", "")) == tone:
			return str(value.get("text", ""))
	return fallback


func _archive_last_segment(segments: Array, tone: String, fallback: String) -> String:
	for index in range(segments.size() - 1, -1, -1):
		var value: Variant = segments[index]
		if value is Dictionary and str(value.get("tone", "")) == tone:
			return str(value.get("text", ""))
	return fallback


func _archive_first_tone(segments: Array) -> String:
	for value in segments:
		if value is Dictionary:
			return str(value.get("tone", ""))
	return ""


func _archive_append_unique(values: Array, name: String) -> void:
	if not name.is_empty() and not values.has(name):
		values.append(name)


## Exclusão só para arquivo já congelado e com confirmação explícita da UI.
## Remove apenas arquivos conhecidos dentro do diretório UUID desta campanha.
func delete_archived_campaign(campaign_id: String, confirmed: bool = false) -> Dictionary:
	if not confirmed or not is_archived(campaign_id):
		return {"success": false, "reason": "Confirme a exclusão permanente do arquivo."}
	return _delete_campaign_files(campaign_id)


## Abandonar é diferente de sair sem salvar: remove os três slots, backup
## automático e livro, inclusive linhas de desfecho. Nunca arquiva.
func abandon_campaign(campaign_id: String, confirmed: bool = false) -> Dictionary:
	if not confirmed or not _valid_id(campaign_id) or is_archived(campaign_id):
		return {"success": false, "reason": "Confirme o abandono da campanha ativa."}
	return _delete_campaign_files(campaign_id)


func _delete_campaign_files(campaign_id: String) -> Dictionary:
	var folder := _campaign_folder(campaign_id)
	var terminal_dir := DirAccess.open(_terminal_folder(campaign_id))
	var main_dir := DirAccess.open(folder)
	if main_dir == null:
		return {"success": true} if not DirAccess.dir_exists_absolute(
			ProjectSettings.globalize_path(folder)) else \
			{"success": false, "reason": "Não foi possível abrir a campanha."}
	var known_files := ["archive.json", "autosave.pppsave", "autosave.pppsave.bak",
		"session.open"]
	for index in range(1, SLOT_COUNT + 1):
		known_files.append("slot_%d.pppsave" % index)
		known_files.append("slot_%d.pppsave.bak" % index)
	for filename in main_dir.get_files():
		if filename not in known_files:
			return {"success": false, "reason": "Arquivo desconhecido; exclusão cancelada."}
	if terminal_dir != null:
		for filename in terminal_dir.get_files():
			var line_id := filename.trim_suffix(".pppline") \
				if filename.ends_with(".pppline") else filename.trim_suffix(".pppmeta")
			if (not filename.ends_with(".pppline") and not filename.ends_with(".pppmeta")) \
					or not _valid_id(line_id):
				return {"success": false, "reason": "Arquivo desconhecido; exclusão cancelada."}
		if not terminal_dir.get_directories().is_empty():
			return {"success": false, "reason": "Subdiretório desconhecido; exclusão cancelada."}
	var subfolders := main_dir.get_directories()
	if subfolders.size() > 1 or (subfolders.size() == 1 \
			and subfolders[0] != "terminal_lines"):
		return {"success": false, "reason": "Subdiretório desconhecido; exclusão cancelada."}
	if terminal_dir != null:
		for filename in terminal_dir.get_files():
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(
					_terminal_folder(campaign_id).path_join(filename))) != OK:
				return {"success": false, "reason": "Não foi possível excluir um desfecho."}
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(
				_terminal_folder(campaign_id))) != OK:
			return {"success": false, "reason": "Não foi possível excluir o diretório de desfechos."}
	for filename in main_dir.get_files():
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(
				folder.path_join(filename))) != OK:
			return {"success": false, "reason": "Não foi possível excluir um save."}
	if DirAccess.remove_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return {"success": false, "reason": "Não foi possível concluir a exclusão."}
	return {"success": true}


func _read_terminal_line(path: String, campaign_id: String) -> Dictionary:
	if not _valid_id(campaign_id) or not FileAccess.file_exists(path):
		return {"success": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_SAVE_BYTES:
		return {"success": false}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"success": false}
	var envelope := parsed as Dictionary
	var payload_json := str(envelope.get("payload_json", ""))
	if envelope.get("kind") != "terminal_line" \
			or int(envelope.get("format_version", -1)) != FORMAT_VERSION \
			or not _valid_id(str(envelope.get("line_id", ""))) \
			or payload_json.sha256_text() != str(envelope.get("payload_sha256", "")):
		return {"success": false}
	var payload: Variant = JSON.parse_string(payload_json)
	if not payload is Dictionary or payload.get("campaign_id") != campaign_id \
			or int(payload.get("status", -1)) not in [CampaignState.CampaignStatus.VICTORY,
			CampaignState.CampaignStatus.DEFEAT] or not payload.get("entries") is Array:
		return {"success": false}
	for value in payload["entries"]:
		if not value is Dictionary or not value.has("serial") \
				or not value.has("action_id") or not value.has("text"):
			return {"success": false}
	return {"success": true, "campaign_id": campaign_id,
		"line_id": str(envelope["line_id"]),
		"created_at": str(envelope.get("created_at", "")),
		"status": int(payload["status"]), "mode": int(payload.get("mode", 0)),
		"journal_schema_version": int(payload.get("journal_schema_version", 1)),
		"ending_ids": payload.get("ending_ids", []), "entries": payload["entries"]}


func apply_to_scene(scene_root: Node, decoded: Dictionary) -> Dictionary:
	var restored := decoded.get("campaign") as CampaignState
	var gerencia := scene_root.get_node_or_null("GerenciaJogo") as GerenciaJogo
	if restored == null or gerencia == null:
		return {"success": false, "reason": "Cena de campanha inválida."}
	var runtime: Dictionary = decoded.get("runtime", {})
	for node_name in RUNTIME_FIELDS:
		if not runtime.has(node_name) or scene_root.get_node_or_null(NodePath(node_name)) == null:
			return {"success": false, "reason": "Controlador não corresponde ao save: %s" % node_name}
		if not runtime[node_name] is Dictionary:
			return {"success": false, "reason": "Estado do controlador inválido: %s" % node_name}
		for field in RUNTIME_FIELDS[node_name]:
			if not runtime[node_name].has(field):
				if OPTIONAL_RUNTIME_FIELDS.get(node_name, []).has(field):
					continue
				return {"success": false,
					"reason": "Campo de controlador ausente: %s" % field}
	# Manter a instância observada pela HUD e pelos visuais preserva todos os
	# sinais conectados em _ready. O conteúdo dela vem integralmente do save.
	var living_campaign := gerencia.campaign
	for property in living_campaign.get_property_list():
		if int(property.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var field := str(property.name)
		var existing: Variant = living_campaign.get(field)
		var value: Variant = restored.get(field)
		if existing is Array and value is Array:
			existing.clear()
			for item in value:
				existing.append(item)
			living_campaign.set(field, existing)
		else:
			living_campaign.set(field, value)
	# O mapa é desenhado a partir dos 40 hexes restaurados; não há sorteio.
	if living_campaign.current_map != null and gerencia.map_view != null:
		gerencia.map_view.show_generated_map(living_campaign.current_map)
		gerencia.map_view.set_visual_effects(living_campaign.get_active_visual_weather(),
			living_campaign.are_infernal_portals_visuals_active())
	for node_name in RUNTIME_FIELDS:
		var node := scene_root.get_node(NodePath(node_name))
		var values: Dictionary = runtime[node_name]
		for field in RUNTIME_FIELDS[node_name]:
			if not values.has(field) and OPTIONAL_RUNTIME_FIELDS.get(node_name, []).has(field):
				continue
			var existing: Variant = node.get(field)
			var value: Variant = values[field]
			if existing is Array and value is Array:
				existing.clear()
				for item in value:
					existing.append(item)
				node.set(field, existing)
			else:
				node.set(field, value)
	var skill_manager := scene_root.get_node("SkillManager") as SkillManager
	skill_manager.inventory_manager._pending_deliveries.clear()
	for delivery in runtime.get("skill_inventory_pending", []):
		skill_manager.inventory_manager._pending_deliveries.append(delivery)
	var executor := scene_root.get_node("EventExecutor") as EventExecutor
	executor._inventory_manager._pending_deliveries.clear()
	for delivery in runtime.get("event_inventory_pending", []):
		executor._inventory_manager._pending_deliveries.append(delivery)
	var exploration := scene_root.get_node("ExplorationManager") as ExplorationManager
	exploration._sync_view()
	var playable_view := scene_root.get_node_or_null("MapRoot/DepthSorted/PlayableActors") as PlayablePartyView
	if playable_view != null:
		playable_view._on_map_entered(living_campaign.current_map)
	var companion_view := scene_root.get_node_or_null("MapRoot/DepthSorted/CompanionActors") as CompanionPartyView
	if companion_view != null:
		companion_view._on_map_entered(living_campaign.current_map)
	var hud := scene_root.get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	if hud != null:
		hud._on_map_generated(living_campaign.current_map)
	var bar := scene_root.get_node_or_null("CampaignTopBar") as CampaignTopBar
	if bar != null:
		bar.bind_campaign(living_campaign)
		bar.refresh()
		bar.journal_ui.bind_campaign(living_campaign)
	var combat := scene_root.get_node("CombatManager") as CombatManager
	if combat.current_encounter != null \
			and not runtime["CombatManager"].has("_loot_entry_max_health"):
		# Saves anteriores à leva 0.5 não tinham o contador. Mantêm o
		# Combate retomável; o limiar é reconstruído com o roster ainda vivo.
		combat._capture_loot_participants()
	if living_campaign.current_map != null \
			and living_campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT:
		if combat._combat_interaction_enabled and gerencia.map_view != null:
			combat._saved_selection_validator = Callable(exploration, "_can_select_hex_for_ui")
			combat._saved_destination_validator = Callable(exploration, "_can_preview_destination")
			gerencia.map_view.selection_validator = Callable(combat, "_can_select_hex")
			gerencia.map_view.destination_validator = Callable(combat, "can_preview_move")
		for enemy in combat.enemies:
			combat._draw_enemy(enemy)
		combat._draw_silhouette_companions(living_campaign)
		combat.bind_initiative_health()
		var journal := scene_root.get_node_or_null("CampaignJournalRecorder") as CampaignJournalRecorder
		if journal != null:
			journal.suspended = true
		combat.combat_prepared.emit(combat.current_encounter, combat.enemies,
			combat.initiative_order)
		if journal != null:
			journal.suspended = false
	var gnomes := scene_root.get_node_or_null("Gnomes2Manager") as Gnomes2Manager
	if gnomes != null and gnomes.active:
		gnomes._clear_visuals()
		gnomes._draw_visuals()
		if gnomes.visual_root != null:
			gnomes.visual_root.visible = living_campaign.current_map != null \
				and living_campaign.current_map.ppp_map_mode != HexGrid.PPPMapMode.COMBAT
	var solo_visual := scene_root.get_node_or_null("SoloEventVisualController") as SoloEventVisualController
	if solo_visual != null:
		solo_visual._refresh_banner()
	return {"success": true}


func _scene_save_readiness(scene_root: Node) -> Dictionary:
	var block := scene_root.get_node_or_null("BlockManager") as BlockManager
	var skills := scene_root.get_node_or_null("PlayerSkillManager") as PlayerSkillManager
	var combat := scene_root.get_node_or_null("CombatManager") as CombatManager
	if block == null or skills == null or combat == null:
		return {"success": false, "reason": "Cena de campanha incompleta."}
	var narrative := scene_root.get_node_or_null("BlockActivationPopup") as BlockActivationPopup
	var narrative_open := narrative != null and narrative.overlay != null \
		and narrative.overlay.visible
	var hud := scene_root.get_node_or_null("PartyStatusHUD") as PartyStatusHUD
	var target_choice_open := hud != null and (hud._pending_tame_target != null \
		or hud._pending_archenemy_target != null)
	var created_item_open := hud != null and hud.created_item_popup != null \
		and hud.created_item_popup.visible
	var bar := scene_root.get_node_or_null("CampaignTopBar") as CampaignTopBar
	var inventory_transaction_open := bar != null and bar.group_inventory != null \
		and (bar.group_inventory.get("_death_owner") != null \
		or bar.group_inventory.get("_exchange_owner") != null \
		or (bar.group_inventory.craft_panel != null \
		and bar.group_inventory.craft_panel.visible))
	var rounds := scene_root.get_node_or_null("RoundManager") as RoundManager
	var district_decision_open := rounds != null and rounds.is_destination_choice_open()
	var combat_waiting_for_player := block.get_phase() == BlockManager.Phase.WAITING_COMBAT \
		and combat.current_encounter != null and combat.is_player_turn() \
		and combat._combat_interaction_enabled \
		and combat.gerencia.campaign.current_map != null \
		and combat.gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT
	var combat_map_active := combat.gerencia != null \
		and combat.gerencia.campaign != null \
		and combat.gerencia.campaign.current_map != null \
		and combat.gerencia.campaign.current_map.ppp_map_mode == HexGrid.PPPMapMode.COMBAT
	if block.get_phase() not in [BlockManager.Phase.IDLE, BlockManager.Phase.WAITING_COMBAT] \
			or (block.get_phase() == BlockManager.Phase.WAITING_COMBAT \
			and not combat_waiting_for_player) \
			or (combat_map_active and not combat_waiting_for_player) \
			or narrative_open or target_choice_open \
			or created_item_open or inventory_transaction_open or district_decision_open \
			or skills.has_pending_choice() or combat._attack_animation_pending \
			or combat._promotion_cleanup_pending or not combat.pending_conclusion.is_empty() \
			or not combat._pending_trap.is_empty() or combat._recruitment_feedback_pending \
			or not combat._pending_recruitment.is_empty():
		return {"success": false,
			"reason": "Aguarde a ação ou decisão atual terminar antes de salvar."}
	return {"success": true}


func _read_envelope(path: String, parse_graph: bool = true) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"success": false}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() <= 0 or file.get_length() > MAX_SAVE_BYTES:
		return {"success": false}
	var raw := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(raw) != OK:
		return {"success": false}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"success": false}
	var envelope := parsed as Dictionary
	if int(envelope.get("format_version", -1)) != FORMAT_VERSION \
			or int(envelope.get("schema_version", -1)) != CampaignState.SCHEMA_VERSION \
			or not _valid_id(str(envelope.get("campaign_id", ""))) \
			or not _valid_id(str(envelope.get("slot_id", ""))):
		return {"success": false}
	var payload_json := str(envelope.get("payload_json", ""))
	if payload_json.is_empty() or payload_json.sha256_text() != envelope.get("payload_sha256"):
		return {"success": false}
	if not parse_graph:
		envelope["success"] = true
		return envelope
	if parser.parse(payload_json) != OK:
		return {"success": false}
	var graph: Variant = parser.data
	if not graph is Dictionary or int(graph.get("graph_version", -1)) \
			!= CampaignSaveCodec.GRAPH_VERSION:
		return {"success": false}
	envelope["graph"] = graph
	envelope["success"] = true
	return envelope


## O catálogo lê apenas o envelope e a prévia protegida por checksum.
## Um arquivo antigo sem prévia recebe rótulo honesto; nunca decodifica o
## grafo só para desenhar a lista. CARREGAR sempre valida o grafo completo.
func _read_catalog_slot(path: String, campaign_id: String,
		slot_number: int) -> Dictionary:
	var envelope := _read_envelope(path, false)
	if not envelope.get("success", false) or envelope.get("campaign_id") != campaign_id \
			or int(envelope.get("slot_number", -1)) != slot_number \
			or str(envelope.get("kind", "manual")) != "manual":
		return {"success": false}
	return envelope


func _read_catalog_autosave(path: String, campaign_id: String) -> Dictionary:
	var envelope := _read_envelope(path, false)
	if not envelope.get("success", false) or envelope.get("campaign_id") != campaign_id \
			or int(envelope.get("slot_number", -1)) != AUTO_SLOT_NUMBER \
			or str(envelope.get("kind", "")) != "autosave":
		return {"success": false}
	return envelope


func _has_verified_preview(envelope: Dictionary) -> bool:
	if envelope.get("preview_json") is String:
		return str(envelope["preview_json"]).sha256_text() \
			== str(envelope.get("preview_sha256", ""))
	return envelope.get("preview") is Dictionary \
		and JSON.stringify(envelope["preview"]).sha256_text() \
		== str(envelope.get("preview_sha256", ""))


func _catalog_preview(envelope: Dictionary) -> Dictionary:
	if _has_verified_preview(envelope):
		if envelope.get("preview_json") is String:
			var parsed: Variant = JSON.parse_string(str(envelope["preview_json"]))
			return parsed if parsed is Dictionary else {"legacy": true}
		return envelope["preview"]
	return {"legacy": true}


func _read_validated_slot(path: String, campaign_id: String,
		slot_number: int) -> Dictionary:
	var envelope := _read_envelope(path)
	if not envelope.get("success", false) or envelope.get("campaign_id") != campaign_id \
			or int(envelope.get("slot_number", -1)) != slot_number \
			or str(envelope.get("kind", "manual")) != "manual" \
			or not _validate_graph(envelope["graph"]):
		return {"success": false}
	return envelope


func _read_validated_autosave(path: String, campaign_id: String) -> Dictionary:
	var envelope := _read_envelope(path)
	if not envelope.get("success", false) or envelope.get("campaign_id") != campaign_id \
			or int(envelope.get("slot_number", -1)) != AUTO_SLOT_NUMBER \
			or str(envelope.get("kind", "")) != "autosave" \
			or not _validate_graph(envelope["graph"]):
		return {"success": false}
	return envelope


func _write_verified(destination: String, envelope: Dictionary,
		previous_primary_valid: bool) -> Dictionary:
	var folder := destination.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		return {"success": false, "reason": "Não foi possível abrir a pasta de saves."}
	var temporary := destination + ".tmp-" + _new_id()
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"success": false, "reason": "Falha ao gravar arquivo temporário."}
	file.store_string(JSON.stringify(envelope))
	file.flush()
	file.close()
	var verified := _read_envelope(temporary)
	if not verified.get("success", false) or not _validate_graph(verified["graph"]):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return {"success": false, "reason": "Arquivo temporário não passou na validação: "
			+ validation_error}
	var absolute_destination := ProjectSettings.globalize_path(destination)
	var absolute_temporary := ProjectSettings.globalize_path(temporary)
	var absolute_backup := ProjectSettings.globalize_path(destination + ".bak")
	if previous_primary_valid:
		if FileAccess.file_exists(destination + ".bak") \
				and DirAccess.remove_absolute(absolute_backup) != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return {"success": false, "reason": "Backup anterior não pôde ser liberado."}
		if DirAccess.rename_absolute(absolute_destination, absolute_backup) != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return {"success": false, "reason": "Save original foi preservado."}
	elif FileAccess.file_exists(destination) \
			and DirAccess.remove_absolute(absolute_destination) != OK:
		DirAccess.remove_absolute(absolute_temporary)
		return {"success": false, "reason": "Arquivo inválido não pôde ser isolado."}
	if DirAccess.rename_absolute(absolute_temporary, absolute_destination) != OK:
		if previous_primary_valid:
			DirAccess.rename_absolute(absolute_backup, absolute_destination)
		DirAccess.remove_absolute(absolute_temporary)
		return {"success": false,
			"reason": "Falha ao concluir gravação; save anterior recuperável."}
	return {"success": true}


func _validate_graph(graph: Dictionary) -> bool:
	validation_error = ""
	var before := InventoryItemState._next_acquisition_order
	var codec := CampaignSaveCodec.new()
	var decoded: Variant = codec.decode(graph)
	var valid := codec.error.is_empty() and decoded is Dictionary \
		and decoded.get("campaign") is CampaignState
	if not valid:
		validation_error = codec.error
	if valid:
		var second_codec := CampaignSaveCodec.new()
		var reencoded := second_codec.encode(decoded)
		var first_text := JSON.stringify(graph)
		var second_text := JSON.stringify(JSON.parse_string(JSON.stringify(reencoded)))
		valid = second_codec.error.is_empty() and first_text == second_text
		if not valid:
			var difference := 0
			while difference < mini(first_text.length(), second_text.length()) \
					and first_text[difference] == second_text[difference]:
				difference += 1
			validation_error = "releitura difere no byte %d; %s" % [difference,
				second_codec.error]
	InventoryItemState._next_acquisition_order = before
	return valid


func _slot_path(campaign_id: String, slot_number: int) -> String:
	return _campaign_folder(campaign_id).path_join("slot_%d.pppsave" % slot_number)


func _terminal_folder(campaign_id: String) -> String:
	return _campaign_folder(campaign_id).path_join("terminal_lines")


func _terminal_path(campaign_id: String, line_id: String) -> String:
	return _terminal_folder(campaign_id).path_join(line_id + ".pppline")


func _terminal_meta_path(campaign_id: String, line_id: String) -> String:
	return _terminal_folder(campaign_id).path_join(line_id + ".pppmeta")


func _archive_path(campaign_id: String) -> String:
	return _campaign_folder(campaign_id).path_join("archive.json")


func _autosave_path(campaign_id: String) -> String:
	return _campaign_folder(campaign_id).path_join("autosave.pppsave")


func _session_path(campaign_id: String) -> String:
	return _campaign_folder(campaign_id).path_join("session.open")


func _campaign_folder(campaign_id: String) -> String:
	return storage_root.path_join(campaign_id)


func _valid_id(value: String) -> bool:
	if value.length() != 36:
		return false
	for index in value.length():
		var character := value[index]
		if index in [8, 13, 18, 23]:
			if character != "-":
				return false
		elif character not in "0123456789abcdef":
			return false
	return true


func _new_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4),
		hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
