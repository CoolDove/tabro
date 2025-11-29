extends Control
class_name TableEdit

@onready var titlescroller = $TitleScroller
@onready var titleline = $TitleScroller/TitleLine
@onready var gridscroller = $ScrollContainer
@onready var grid = $ScrollContainer/Grid

var data

func _ready():
	var skills = ResourceLoader.load("res://resources/skills.csv")
	print("data in the table: ", skills.records)
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
			if row_index == 0:
				titleline.add_child(celledit)
				celledit.text = ""
				celledit.push_bold()
				celledit.append_text("%s" % cell)
				celledit.pop()
			else:
				grid.add_child(celledit)
		if row.size() > max_column:
			max_column = row.size()
		row_index += 1
	grid.columns = max_column

func _process(delta):
	titlescroller.scroll_horizontal = gridscroller.scroll_horizontal
