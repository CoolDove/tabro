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

func add_field(name: String):
	var field = FieldData.new()
	field.name = name
	field.width = 140
	fields.append(field)
	if _is_normalized:
		normalize()

func add_record():
	var row : PackedStringArray
	row.resize(fields.size())
	records.append(row)

enum Version {
	V00 = 1,
	VLATEST = V00
}

static func serialize(data: TabroData) -> String:
	var save : Dictionary
	save["version"] = Version.VLATEST
	var body : Dictionary
	save["body"] = body
	# Nerver change above
	var dfields = []
	for field in data.fields:
		var fieldsave = {
			"name" = field.name,
			"width" = field.width,
		}
		dfields.append(fieldsave)
	body["fields"] = dfields
	var drecords : Array[PackedStringArray]
	for record in data.records:
		var row : PackedStringArray
		for cell in record:
			row.append(cell)
		drecords.append(row)
	body["records"] = drecords
	return JSON.stringify(save)

static func deserialize(raw: String) -> TabroData:
	var save = JSON.parse_string(raw)
	var version = save["version"]
	var body = save["body"]
	if version == null or body == null:
		return null

	match version as Version:
		Version.V00:
			return _deserialize_body_v00(body)
		_:
			return null

static func _deserialize_body_v00(jobj) -> TabroData:
	var dfields : Array[FieldData]
	var drecords : Array[PackedStringArray]
	var jfields = jobj["fields"]
	for field in jfields:
		var f = FieldData.new()
		f.name = field["name"]
		f.width = field["width"]
		dfields.append(f)
	for record in jobj["records"]:
		var rowdata : PackedStringArray
		for row in record:
			rowdata.append(row)
		drecords.append(rowdata)
	var data = TabroData.new()
	data.fields = dfields
	data.records = drecords
	return data
