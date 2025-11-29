extends Control
class_name TableEdit

@onready var titlescroller = $TitleScroller
@onready var titleline = $TitleScroller/TitleLine
@onready var gridscroller = $ScrollContainer
@onready var grid = $ScrollContainer/Grid

var data : CsvData

var cell_height = 32.0
var fields : Array[Field]

var _pool_label     : Array[Label]
var _pool_richlabel : Array[RichTextLabel]

class Field:
	var name : String
	var width : int

var _virtual_spacing_before : Control
var _virtual_spacing_after  : Control

var visible_begin : int: # include
	get:
		return floori(gridscroller.scroll_vertical / cell_height) - 1
var visible_end : int: # exclude
	get:
		return ceili((gridscroller.scroll_vertical + gridscroller.size.y) / cell_height)

func _ready():
	# Add a little block to fit the scroll bar width in body scroll container.
	var spacing = Control.new()
	titleline.add_child(spacing, false, INTERNAL_MODE_BACK)
	spacing.custom_minimum_size.x = gridscroller.get_h_scroll_bar().size.x

	# Sync the hscroll of titleline and table body
	gridscroller.get_h_scroll_bar().value_changed.connect(
		func(v):
			titlescroller.scroll_horizontal = v
	)
	titlescroller.get_h_scroll_bar().value_changed.connect(
		func(v):
			gridscroller.scroll_horizontal = v
	)
	gridscroller.get_v_scroll_bar().value_changed.connect(func(_v):
		refresh()
	)
	item_rect_changed.connect(refresh)

	# For virtual spacing the table grid
	_virtual_spacing_before = Control.new()
	_virtual_spacing_before.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_virtual_spacing_before.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_virtual_spacing_after = Control.new()
	_virtual_spacing_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_virtual_spacing_after.size_flags_vertical = Control.SIZE_SHRINK_END

	grid.add_child(_virtual_spacing_before, false, INTERNAL_MODE_FRONT)
	grid.add_child(_virtual_spacing_after, false, INTERNAL_MODE_BACK)

	data = ResourceLoader.load("res://resources/skills.csv") as CsvData

func refresh():
	print("refresh")
	grid.custom_minimum_size.y = cell_height * data.records.size()

	for i in range(0, data.records[0].size() - titleline.get_child_count()):
		titleline.add_child(_get_cell_control_label())
	for i in range(0, titleline.get_child_count() - data.records[0].size()):
		var c = titleline.get_child(-1)
		titleline.remove_child(c)
		_recycle_cell_control_label(c)

	fields.clear()
	for f in data.records[0]:
		var celledit = titleline.get_child(fields.size())
		var field = Field.new()
		field.name = f
		field.width = 160 + hash(f) % 40
		fields.push_back(field)

		# Set field edit
		celledit.theme_type_variation = "TableCell"
		celledit.text = f
		celledit.custom_minimum_size = Vector2(field.width, cell_height)

	for i in range(0, data.records.size() - 1 - grid.get_child_count()):
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		grid.add_child(line)
	for i in range(0, grid.get_child_count() - data.records.size() - 1):
		_recycle_free_line(grid.get_child(-1))

	var field_count = fields.size()
	for line in grid.get_children():
		for f in range(0, field_count - line.get_child_count()):
			line.add_child(_get_cell_control_label())
		for f in range(0, line.get_child_count() - field_count):
			line.remove_child(line.get_child(-1))

	for r in range(1, data.records.size()):
		var row = data.records[r]
		var linectnr = grid.get_child(r-1)
		for f in range(0, row.size()):
			var celledit = linectnr.get_child(f)
			# Set cell edit
			celledit.theme_type_variation = "TableCell"
			celledit.text = "%s" % row[f]
			celledit.set("clip_text", true)
			celledit.custom_minimum_size = Vector2(fields[f].width, cell_height)

func _recycle_free_line(line: HBoxContainer):
	for e in line:
		if e is Label:
			_recycle_cell_control_label(e)
		else:
			if e is RichTextLabel:
				_recycle_cell_control_richlabel(e)
			else:
				e.queue_free()
	line.queue_free()

func _get_cell_control_label() -> Label:
	var result = _pool_label.pop_back()
	return result if result != null else Label.new()

func _recycle_cell_control_label(lb: Label):
	_pool_label.push_back(lb)

func _get_cell_control_richlabel() -> RichTextLabel:
	var result = _pool_richlabel.pop_back()
	return result if result != null else RichTextLabel.new()

func _recycle_cell_control_richlabel(lb: RichTextLabel):
	_pool_richlabel.push_back(lb)
