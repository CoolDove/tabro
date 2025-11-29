extends Control
class_name TableEdit

@onready var grid = $ScrollContainer/Grid

func _ready():
	var skills = ResourceLoader.load("res://resources/skills.csv")
	print("data in the table: ", skills.records)
	var max_column = 0
	for row in skills.records:
		for cell in row:
			var celledit = LineEdit.new()
			celledit.text = "%s" % cell
			celledit.custom_minimum_size = Vector2(120, 32)
			grid.add_child(celledit)
		if row.size() > max_column:
			max_column = row.size()
	grid.columns = max_column
	
