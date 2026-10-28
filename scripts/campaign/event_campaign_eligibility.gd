class_name EventCampaignEligibility
extends RefCounted

# Política por ID estável e tag validada; nunca inferir pelo texto do Evento.
enum Mode { SHORT, MEDIUM, COMPLETE }

const COMPLETE_ONLY: StringName = &"somente_campanha_completa"


static func allows_event(event: EventData, mode: int) -> bool:
	return event != null and _valid_mode(mode) \
		and (mode == Mode.COMPLETE or not EventCampaignDependencies.is_complete_only_event_id(
			event.id) and COMPLETE_ONLY not in event.tags)


static func allows_outcome(outcome: EventOutcomeData, mode: int) -> bool:
	return outcome != null and _valid_mode(mode) \
		and (mode == Mode.COMPLETE or not EventCampaignDependencies.is_complete_only_outcome(
			EventCampaignDependencies.GENIE_EVENT_ID, outcome.id)
			and COMPLETE_ONLY not in outcome.tags)


static func _valid_mode(mode: int) -> bool:
	return mode in [Mode.SHORT, Mode.MEDIUM, Mode.COMPLETE]
