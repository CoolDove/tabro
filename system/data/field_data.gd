extends Resource
class_name FieldData

# All of this will be serialized.

@export var name : String
@export var type : Main.FieldType
@export var width : int

## Field Configs

# FieldType.OPTION and FieldType.MULTI_OPTION both use this.
@export var toption_options : Array
@export var toption_colors  : Array
@export var toption_multiple : bool

@export var tcode_code : String


static func parse_standardized_options(data: String) -> Array:
	var options = []
	var valid = true
	if valid and data.begins_with(">"):
		var raw_indexes = data.substr(1).split(",")
		for index in raw_indexes:
			if index.is_valid_int():
				var idx = index.to_int()
				options.append(idx)
			else:
				valid = false
				break
	if valid:
		return options
	else:
		return []
