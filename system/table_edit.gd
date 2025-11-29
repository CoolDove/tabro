extends Control
class_name TableEdit

@onready var titlescroller = $TitleScroller
@onready var titleline = $TitleScroller/TitleLine
@onready var gridscroller = $ScrollContainer
@onready var grid = $ScrollContainer/Grid

var data

var fields : Array[Field]

class Field:
	var name : String
	var width : int

func _ready():
	gridscroller.get_h_scroll_bar().value_changed.connect(\
			func(v):
				titlescroller.scroll_horizontal = v)
	var skills = ResourceLoader.load("res://resources/skills.csv")
	data = skills.records
	var max_column = 0
	var row_index = 0
	for row in data:
		for cell in row:
			var celledit = RichTextLabel.new()
			celledit.scroll_active = false
			celledit.text = "%s" % cell
			celledit.bbcode_enabled = true
			celledit.custom_minimum_size = Vector2(150, 32)
			if row_index == 0: # header
				var field = Field.new()
				field.name = cell
				field.width = 160
				fields.append(field)
				celledit.text = "[b]%s[/b]" % cell
				titleline.add_child(celledit)
			else:
				grid.add_child(celledit)
		if row.size() > max_column:
			max_column = row.size()
		row_index += 1
	grid.columns = skills.column
