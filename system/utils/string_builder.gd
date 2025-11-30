class_name StringBuilder

class Builder:
	var buffer : PackedByteArray
	func append(v):
		if v == null:
			return
		if v is String:
			buffer.append_array(v.to_utf8_buffer())
		elif v is StringName:
			buffer.append_array(v.to_utf8_buffer())
		else:
			buffer.append_array(("%s" % v).to_utf8_buffer())
	
	func clear():
		buffer.clear()

	func get_string() -> String:
		return buffer.get_string_from_utf8()

static func create():
	return Builder.new()
