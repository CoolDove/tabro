extends Resource
class_name FieldData

@export var name : String
@export var type : Main.FieldType
@export var width : int

## Field Configs

# FieldType.OPTION and FieldType.MULTI_OPTION both use this.
@export var toption_options : Array[String]
@export var toption_colors  : Array[Color]
@export var toption_multiple : bool

@export var tcode_code : String
