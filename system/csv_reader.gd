extends Node

var _regex: RegEx

func _init():
	_regex = RegEx.new()
	_regex.compile('(?:^|,)(?:"((?:[^"]|"")*)"|([^",]*))')

func load(filepath: String) -> CsvData:
	var delim: String = ","

	var file = FileAccess.open(filepath, FileAccess.READ)
	if not file:
		printerr("Failed to open file: ", filepath)
		return null

	var lines = []
	var max_column = 0
	while not file.eof_reached():
		var line = file.get_csv_line(delim)
		max_column = maxi(line.size(), max_column)
		lines.append(line)
	file.close()

	# Remove trailing empty line
	if not lines.is_empty() and lines.back().size() == 1 and lines.back()[0] == "":
		lines.pop_back()

	var data = CsvData.new()

	data.records = lines
	data.column = max_column

	return data

func parse_csv_lines(text: String) -> Array[PackedStringArray]:
	var lines :PackedStringArray= text.split("\n")
	var results : Array[PackedStringArray]
	results.resize(lines.size())
	var index :int= 0
	for line in lines:
		results[index] = parse_csv_line(line)
		index += 1
	return results

func parse_csv_line(line: String) -> PackedStringArray:
	var matches = _regex.search_all(line)
	if matches.size() == 0:
		return []
	var results : PackedStringArray
	for m in matches:
		var quoted = m.get_string(1)
		var unquoted = m.get_string(2)
		var value: String
		if quoted != "":
			value = quoted.replace('""', '"')
		else:
			value = unquoted
		results.append(value)
	return results
