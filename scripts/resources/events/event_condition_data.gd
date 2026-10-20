class_name EventConditionData
extends Resource

enum ConditionType {
	HAS_INFORMATION,
	IS_NIGHT,
	IS_DAY,
	HAS_TAG,
	CUSTOM
}

@export var condition_type: ConditionType = ConditionType.HAS_INFORMATION
@export var negate: bool = false
@export var tag: StringName
@export var custom_rule: StringName
