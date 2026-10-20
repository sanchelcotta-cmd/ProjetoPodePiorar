extends SceneTree

var failures := 0


func _initialize() -> void:
	var campaign := CampaignState.new()
	_check(campaign.campaign_id.is_empty()
		and campaign.campaign_status == CampaignState.CampaignStatus.NOT_STARTED,
		"Sem partida iniciada não há identidade de campanha ativa.")
	_check(campaign.schema_version == CampaignState.SCHEMA_VERSION,
		"A versão do modelo é explícita.")
	var selected: Array[EntityData] = [
		load("res://resources/entities/entities_playable/cozinheiro.tres"),
		load("res://resources/entities/entities_playable/pedreiro.tres"),
		load("res://resources/entities/entities_playable/mae.tres")]
	_check(campaign.start_new_game(selected), "A primeira campanha inicia.")
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	var first_id := campaign.campaign_id
	_check(uuid_pattern.search(first_id) != null, "A campanha ganha um UUID v4 estável.")
	_check(campaign.campaign_mode == EventCampaignEligibility.Mode.COMPLETE
		and campaign.active_ending_ids.size() == 4
		and campaign.has_active_ending(&"orchestra")
		and campaign.has_active_ending(&"khainokata")
		and campaign.has_active_ending(&"homens_de_preto")
		and campaign.has_active_ending(&"controle_da_mente"),
		"Enquanto não há seleção de modo, a campanha completa tem quatro desfechos.")
	_check(campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE
		and not campaign.is_terminal(), "Partida recém-iniciada não é terminal.")
	var invalid: Array[EntityData] = [selected[0], selected[0], selected[2]]
	_check(not campaign.start_new_game(invalid) and campaign.campaign_id == first_id,
		"Seleção inválida não substitui a identidade.")
	_check(campaign.mark_terminal(CampaignState.CampaignStatus.VICTORY)
		and campaign.is_terminal(), "Vitória pode ser registrada uma vez.")
	_check(not campaign.mark_terminal(CampaignState.CampaignStatus.DEFEAT)
		and campaign.campaign_status == CampaignState.CampaignStatus.VICTORY,
		"Resultado terminal não pode ser sobrescrito.")
	_check(campaign.start_new_game(selected), "Nova partida válida inicia.")
	_check(campaign.campaign_id != first_id
		and uuid_pattern.search(campaign.campaign_id) != null
		and campaign.campaign_status == CampaignState.CampaignStatus.ACTIVE,
		"Nova partida ganha outro ID e volta ao estado ativo.")
	_check(not campaign.mark_terminal(CampaignState.CampaignStatus.NOT_STARTED)
		and not campaign.is_terminal(), "Estado não terminal não encerra a campanha.")
	print("CAMPAIGN_IDENTITY_TEST: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
