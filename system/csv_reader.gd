class_name CsvReader

static func load(filepath) -> CsvData:
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
