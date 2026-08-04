extends RefCounted
class_name Modifier

const PERMANENT_DURATION: float = -1.0
const DEFAULT_PRIORITY: int = 500

const OPERATION_ADD_FLAT: String = "add_flat"
const OPERATION_ADD_PERCENT: String = "add_percent"
const OPERATION_MULTIPLY: String = "multiply"
const OPERATION_OVERRIDE: String = "override"
const OPERATION_MIN_CAP: String = "min_cap"
const OPERATION_MAX_CAP: String = "max_cap"

const STACK_RULE_UNIQUE: String = "unique"
const STACK_RULE_REPLACE_SAME_SOURCE: String = "replace_same_source"
const STACK_RULE_STACK_ADD: String = "stack_add"
const STACK_RULE_STACK_WITH_LIMIT: String = "stack_with_limit"
const STACK_RULE_REFRESH_DURATION: String = "refresh_duration"
const STACK_RULE_EXCLUSIVE_GROUP: String = "exclusive_group"

const VALID_OPERATIONS: Array[String] = [
	OPERATION_ADD_FLAT,
	OPERATION_ADD_PERCENT,
	OPERATION_MULTIPLY,
	OPERATION_OVERRIDE,
	OPERATION_MIN_CAP,
	OPERATION_MAX_CAP,
]

const VALID_STACK_RULES: Array[String] = [
	STACK_RULE_UNIQUE,
	STACK_RULE_REPLACE_SAME_SOURCE,
	STACK_RULE_STACK_ADD,
	STACK_RULE_STACK_WITH_LIMIT,
	STACK_RULE_REFRESH_DURATION,
	STACK_RULE_EXCLUSIVE_GROUP,
]

const REQUIRED_FIELDS: Array[String] = [
	"id",
	"source_type",
	"source_id",
	"target_scope",
	"stat",
	"operation",
	"value",
	"duration",
	"stack_rule",
]

var id: String = ""
var source_type: String = ""
var source_id: String = ""
var target_scope: String = ""
var stat: String = ""
var operation: String = OPERATION_ADD_FLAT
var value: float = 0.0
var duration: float = PERMANENT_DURATION
var stack_rule: String = STACK_RULE_UNIQUE
var priority: int = DEFAULT_PRIORITY
var tags: Array[String] = []
var metadata: Dictionary = {}
var missing_fields: Array[String] = []


static func from_dictionary(data: Dictionary) -> Modifier:
	var modifier := Modifier.new()
	modifier.load_from_dictionary(data)
	return modifier


func load_from_dictionary(data: Dictionary) -> void:
	missing_fields.clear()
	for field_name in REQUIRED_FIELDS:
		if not data.has(field_name):
			missing_fields.append(field_name)
	id = str(data.get("id", ""))
	source_type = str(data.get("source_type", ""))
	source_id = str(data.get("source_id", ""))
	target_scope = str(data.get("target_scope", ""))
	stat = str(data.get("stat", ""))
	operation = str(data.get("operation", OPERATION_ADD_FLAT))
	value = float(data.get("value", 0.0))
	duration = float(data.get("duration", PERMANENT_DURATION))
	stack_rule = str(data.get("stack_rule", STACK_RULE_UNIQUE))
	priority = int(data.get("priority", DEFAULT_PRIORITY))
	tags = _to_string_array(data.get("tags", []))
	metadata = data.get("metadata", {}).duplicate(true)


func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"source_type": source_type,
		"source_id": source_id,
		"target_scope": target_scope,
		"stat": stat,
		"operation": operation,
		"value": value,
		"duration": duration,
		"stack_rule": stack_rule,
		"priority": priority,
		"tags": tags.duplicate(),
		"metadata": metadata.duplicate(true),
	}


func duplicate_modifier() -> Modifier:
	return Modifier.from_dictionary(to_dictionary())


func validate() -> Array[String]:
	var errors: Array[String] = []
	for field_name in missing_fields:
		errors.append("Missing required modifier field: %s" % field_name)

	if id.strip_edges().is_empty():
		errors.append("Modifier id cannot be empty.")
	if source_type.strip_edges().is_empty():
		errors.append("Modifier source_type cannot be empty: %s" % id)
	if source_id.strip_edges().is_empty():
		errors.append("Modifier source_id cannot be empty: %s" % id)
	if target_scope.strip_edges().is_empty():
		errors.append("Modifier target_scope cannot be empty: %s" % id)
	if stat.strip_edges().is_empty():
		errors.append("Modifier stat cannot be empty: %s" % id)
	if not is_valid_operation(operation):
		errors.append("Modifier has invalid operation '%s': %s" % [operation, id])
	if not is_valid_stack_rule(stack_rule):
		errors.append("Modifier has invalid stack_rule '%s': %s" % [stack_rule, id])
	if duration < 0.0 and not is_permanent():
		errors.append("Modifier duration must be positive or PERMANENT_DURATION: %s" % id)
	return errors


func is_valid() -> bool:
	return validate().is_empty()


func is_permanent() -> bool:
	return is_equal_approx(duration, PERMANENT_DURATION)


func is_expired() -> bool:
	return not is_permanent() and duration <= 0.0


func tick(delta: float) -> void:
	if is_permanent():
		return
	duration = maxf(duration - delta, 0.0)


func refresh_duration(new_duration: float) -> void:
	duration = new_duration


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func has_any_tag(query_tags: Array[String]) -> bool:
	for tag in query_tags:
		if tags.has(tag):
			return true
	return false


func matches_source(query_source_type: String, query_source_id: String) -> bool:
	return source_type == query_source_type and source_id == query_source_id


func get_stack_key() -> String:
	match stack_rule:
		STACK_RULE_REPLACE_SAME_SOURCE:
			return "%s:%s:%s:%s" % [source_type, source_id, target_scope, stat]
		STACK_RULE_EXCLUSIVE_GROUP:
			return str(metadata.get("exclusive_group", id))
		_:
			return id


static func is_valid_operation(query_operation: String) -> bool:
	return VALID_OPERATIONS.has(query_operation)


static func is_valid_stack_rule(query_stack_rule: String) -> bool:
	return VALID_STACK_RULES.has(query_stack_rule)


static func _to_string_array(value_data: Variant) -> Array[String]:
	var result: Array[String] = []
	if value_data is Array:
		for item in value_data:
			result.append(str(item))
	return result

