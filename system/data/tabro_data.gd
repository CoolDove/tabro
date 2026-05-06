extends Resource
class_name TabroData

@export var fields : Array[FieldData]
@export var records : Array # 默认类型是String，Option类型是Array[int]

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

func add_field(name: String, type:= Main.FieldType.STRING) -> FieldData:
	var field = FieldData.new()
	field.name = name
	field.type = type
	field.width = 140
	fields.append(field)
	if _is_normalized:
		normalize()
	return field

func add_record() -> Array:
	var row : Array
	row.resize(fields.size())
	records.append(row)
	return row

enum Version {
	V00,
	V01,
	V02,
	VLATEST = V02 # Update this when you add a new version.
}

static func serialize(data: TabroData) -> String:
	var save : Dictionary
	save["version"] = Version.VLATEST
	var body : Dictionary
	save["body"] = body
	# Nerver change above
	var dfields = []
	for field in data.fields:
		var dict : Dictionary
		for property in field.get_property_list():
			if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE > 0:
				var pname = property["name"]
				dict[pname] = field.get(pname)
		dfields.append(dict)
	body["fields"] = dfields
	var drecords : Array[PackedStringArray]
	for record in data.records:
		var row : PackedStringArray
		for cell in record:
			row.append(cell)
		drecords.append(row)
	body["records"] = drecords
	return JSON.stringify(save, "\t")

static func deserialize(raw: String) -> TabroData:
	var save = JSON.parse_string(raw)
	if save == null:
		return null
	var version = save["version"]
	var body = save["body"]
	if version == null or body == null:
		return null

	match version as Version:
		Version.V00:
			return _deserialize_body_v00(body)
		Version.V01:
			return _deserialize_body_v01(body)
		Version.V02:
			return _deserialize_body_v02(body)
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

static func _deserialize_body_v01(jobj) -> TabroData:
	var dfields : Array[FieldData]
	var drecords : Array[PackedStringArray]
	var jfields = jobj["fields"]
	for field in jfields:
		var f = FieldData.new()
		f.name = field["name"]
		f.type = field["type"]
		f.width = field["width"]
		print("deserlz field: %s of type %s" % [f.name, f.type])
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

static func _deserialize_body_v02(jobj) -> TabroData:
	var dfields : Array[FieldData]
	var drecords : Array
	var jfields = jobj["fields"]
	for field in jfields:
		var f = FieldData.new()
		for jf in field:
			f.set(jf, field[jf])
		dfields.append(f)
	for record in jobj["records"]:
		var rowdata : Array
		for row in record:
			rowdata.append(row)
		drecords.append(rowdata)
	var data = TabroData.new()
	data.fields = dfields
	data.records = drecords
	return data
