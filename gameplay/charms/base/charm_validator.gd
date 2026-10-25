class_name CharmValidator
extends RefCounted
## Kiểm tra data Charm trước khi đưa vào registry.


static func validate_data(definition: CharmData) -> PackedStringArray:
	if definition == null:
		return PackedStringArray(["definition must not be null"])
	return definition.validate()


static func validate_catalog(definitions: Array[CharmData]) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary[StringName, bool] = {}
	for definition: CharmData in definitions:
		var definition_errors := validate_data(definition)
		for error: String in definition_errors:
			errors.append(error)
		if definition == null or definition.charm_id.is_empty():
			continue
		if seen_ids.has(definition.charm_id):
			errors.append("duplicate charm_id: %s" % definition.charm_id)
		else:
			seen_ids[definition.charm_id] = true
	return errors
