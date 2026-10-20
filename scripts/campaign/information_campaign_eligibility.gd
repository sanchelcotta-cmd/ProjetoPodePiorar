class_name InformationCampaignEligibility
extends RefCounted

## Fonte única de elegibilidade para Informações de campanha. O título e a
## descrição são apresentação; somente ID, tag e tipo entram nesta regra.
const INFORMATION_DIRECTORY := "res://resources/informacoes"
const ENDING_IDS: Array[StringName] = [&"khainokata", &"orchestra",
	&"homens_de_preto", &"controle_da_mente"]

static var _catalog_by_id: Dictionary = {} # Informacao.id -> desfecho
static var _seen_ids: Dictionary = {}
static var _catalog_errors: Array[String] = []
static var _catalog_loaded := false


static func ending_for_type(information_type: int) -> StringName:
	match information_type:
		Informacao.TipoInformacao.KHAINOKATA:
			return &"khainokata"
		Informacao.TipoInformacao.ORCHESTRA:
			return &"orchestra"
		Informacao.TipoInformacao.HOMENS_DE_PRETO:
			return &"homens_de_preto"
		Informacao.TipoInformacao.CONTROLE_DA_MENTE:
			return &"controle_da_mente"
	return &""


static func ending_for_id(information_id: StringName) -> StringName:
	_load_catalog()
	return _catalog_by_id.get(information_id, &"") as StringName


## Com ID, consulta o Resource cadastrado e confere o tipo quando fornecido.
## Sem ID, o tipo isolado basta. O conjunto de desfechos vem do CampaignState,
## nunca da tela que chama esta função.
static func is_eligible(active_endings: Array[StringName],
		information_id: StringName = &"", information_type: int = -1) -> bool:
	var ending_id := &""
	if information_id != &"":
		ending_id = ending_for_id(information_id)
		if ending_id == &"":
			return false
		if information_type >= 0 and ending_id != ending_for_type(information_type):
			return false
	else:
		ending_id = ending_for_type(information_type)
	return ending_id != &"" and ending_id in active_endings


static func catalog_errors() -> Array[String]:
	_load_catalog()
	return _catalog_errors.duplicate()


static func catalog_size() -> int:
	_load_catalog()
	return _catalog_by_id.size()


static func _load_catalog() -> void:
	if _catalog_loaded:
		return
	_catalog_loaded = true
	_scan_directory(INFORMATION_DIRECTORY)


static func _scan_directory(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".tres"):
			continue
		var path := directory.path_join(filename)
		var information := load(path) as Informacao
		if information == null or information.id == &"":
			_catalog_errors.append("Informação inválida ou sem ID: %s" % path)
			continue
		if _seen_ids.has(information.id):
			_catalog_errors.append("ID de Informação duplicado: %s" % information.id)
			_catalog_by_id.erase(information.id)
			continue
		_seen_ids[information.id] = true
		var found: Array[StringName] = []
		for ending_id in ENDING_IDS:
			if ending_id in information.tags:
				found.append(ending_id)
		if found.size() != 1:
			_catalog_errors.append("Informação %s precisa de uma tag de desfecho." % information.id)
			continue
		if ending_for_type(information.tipo) != found[0]:
			_catalog_errors.append("Tipo e tag divergem na Informação %s." % information.id)
			continue
		_catalog_by_id[information.id] = found[0]
	for subdirectory in DirAccess.get_directories_at(directory):
		_scan_directory(directory.path_join(subdirectory))
