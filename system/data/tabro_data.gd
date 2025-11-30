extends Resource
class_name TabroData

@export var fields : Array[FieldData]
@export var records : Array[PackedStringArray]

var is_normalized :bool:
	get:
		return _is_normalized
var _is_normalized = false

# Have to do this before really using this in TabroEdit.
func normalize():
	_is_normalized = true
	var fields_count = fields.size()
	for row in records:
		row.resize(fields_count)
