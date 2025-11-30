extends Control
class_name TableEdit

@onready var titlescroller = $TitleScroller
@onready var titleline = $TitleScroller/TitleLine
@onready var gridscroller = $ScrollContainer
@onready var grid = $ScrollContainer/Grid

@onready var _grid_hover_highlight_mark = $HoverHighlightMark


var cell_value_edit : CellValueEdit

var data : CsvData:
	get:
		return _data
	set(v):
		_data = v
		call_deferred("refresh")
var _data : CsvData

var cell_height = 32.0
var fields : Array[Field]

var _pool_label : Node # Array[Label]

var select_region : Rect2i
var hover_cell : Vector2i
var is_hover_cell_valid :bool:
	get:
		return hover_cell.x >= 0 and hover_cell.y >= 0

class Field:
	var name : String
	var width : int

var _virtual_spacing_before : Control
var _virtual_spacing_after  : Control

var visible_begin : int: # include
	get:
		return floori(gridscroller.scroll_vertical / cell_height)
var visible_end : int: # exclude
	get:
		return ceili((gridscroller.scroll_vertical + gridscroller.size.y) / cell_height)

func _init(csvdata:CsvData=null):
	data = csvdata
	pass

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

	# Visual stuff
	remove_child(_grid_hover_highlight_mark)

func _enter_tree():
	_pool_label = Node.new()

func _exit_tree():
	_pool_label.queue_free()

func _gui_input(event):
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton:
		if Input.is_key_pressed(KEY_CTRL):
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					var th = Main.instance.theme
					th.default_font_size = min(th.default_font_size + 1, 64)
					refresh()
				MOUSE_BUTTON_WHEEL_DOWN:
					var th = Main.instance.theme
					th.default_font_size = max(th.default_font_size - 1, 12)
					refresh()
		else:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					if event.is_released() and is_hover_cell_valid:
						var celledit = _get_celledit_from_hover_cell(hover_cell)
						var data_row_idx = hover_cell.y + 1
						var data_col_idx = hover_cell.x
						var fieldinfo = fields[hover_cell.x]
						if celledit != null:
							var edit = CellValueEdit.new(data.records[data_row_idx][data_col_idx], CellValueEdit.CellType.STRING) 
							var twn = create_tween()
							edit.size = Vector2(fieldinfo.width, cell_height)
							edit.modulate = Color(1,1,1,0)
							twn.parallel().tween_property(edit, "size", Vector2(fieldinfo.width, 220), 0.1)
							twn.parallel().tween_property(edit, "modulate", Color.WHITE, 0.2)
							add_child(edit)
							edit.global_position = celledit.global_position
							cell_value_edit = edit
							edit.on_edit_finish.connect(func(value):
								data.records[data_row_idx][data_col_idx] = value
								call_deferred("refresh")
							)
		_update_hover()

var _watch_mem_interval : float
var _watch_mem_pool_count : int
var _watch_mem_pool_count_last : int
var _watch_mem_pool_target : int
func _process(delta):
	# Watch memory
	if _watch_mem_interval >= 0:
		_watch_mem_interval -= delta
	if _watch_mem_interval < 0:
		_watch_mem_pool_count = _pool_label.get_child_count()
		var kill = false
		if _watch_mem_pool_count >= _watch_mem_pool_count_last:
			kill = true
		else:
			var d = _watch_mem_pool_count_last - _watch_mem_pool_count
			kill = d < _watch_mem_pool_target * 0.5 and _watch_mem_pool_target < _watch_mem_pool_count
		if kill:
			for i in range(0, _watch_mem_pool_target):
				_pool_label.get_child(-1-i).queue_free()
		_watch_mem_pool_target = int(_watch_mem_pool_count * 0.5)
		_watch_mem_pool_count_last = _watch_mem_pool_count
		_watch_mem_interval = 5

func _update_hover():
	var grid_mpos = gridscroller.get_local_mouse_position()
	var new_hover_cell
	var is_outside = grid_mpos.x < 0 or grid_mpos.y < 0 or grid_mpos.x > gridscroller.size.x or grid_mpos.y > gridscroller.size.y
	if is_outside or cell_value_edit != null:
		new_hover_cell = Vector2i(-1,-1)
	else:
		var hovery = floori((grid_mpos.y + gridscroller.scroll_vertical) / cell_height)
		var _hoverxpx = int(grid_mpos.x + gridscroller.scroll_horizontal)
		var hoverx = 0
		for fieldidx in range(0, fields.size()):
			hoverx = fieldidx
			var field = fields[fieldidx]
			if _hoverxpx < field.width:
				break
			_hoverxpx -= field.width
		new_hover_cell = Vector2i(hoverx, hovery)
	if new_hover_cell == hover_cell:
		return
	var new_hover_celledit = _get_celledit_from_hover_cell(new_hover_cell)
	if hover_cell != new_hover_cell:
		var old_parent = _grid_hover_highlight_mark.get_parent()
		if old_parent != null:
			old_parent.remove_child(_grid_hover_highlight_mark)
		if new_hover_celledit != null:
			_grid_hover_highlight_mark.set_anchors_preset(PRESET_FULL_RECT)
			new_hover_celledit.add_child(_grid_hover_highlight_mark, false, INTERNAL_MODE_BACK)
		queue_redraw()
	hover_cell = new_hover_cell
	await get_tree().process_frame

func _get_celledit_from_hover_cell(hover: Vector2i) -> Control:
	if hover.x < 0 or hover.y < 0 or hover.y > data.records.size() - 2 or hover.x > fields.size() - 1:
		return null
	var linectnr = grid.get_child(hover.y - visible_begin)
	if linectnr == null:
		return null
	return linectnr.get_child(hover.x) as Control

func refresh():
	if data == null:
		return

	var th = Main.instance.theme
	cell_height = max(th.default_font.get_height(th.default_font_size) + 12, 28)

	grid.custom_minimum_size.y = cell_height * data.records.size()

	_virtual_spacing_before.custom_minimum_size = Vector2(0, visible_begin * cell_height)
	_virtual_spacing_after.custom_minimum_size  = Vector2(0, int(gridscroller.size.y * 0.4))

	for i in range(0, data.records[0].size() - titleline.get_child_count()):
		titleline.add_child(_get_cell_control_label())
	for i in range(0, titleline.get_child_count() - data.records[0].size()):
		var c = titleline.get_child(-1)
		titleline.remove_child(c)
		_recycle_cell_control_label(c)

	fields.clear()
	for f in data.records[0]:
		var celledit = titleline.get_child(fields.size()) as Label
		var field = Field.new()
		field.name = f
		field.width = 160 + hash(f) % 40
		fields.push_back(field)

		# Set field edit
		_initialize_celledit(celledit)
		celledit.text = f
		celledit.custom_minimum_size = Vector2(field.width, titleline.size.y)

	var visible_record_count = min(\
			visible_end - visible_begin, data.records.size() - 1 - visible_begin
	)
	for i in range(0, visible_record_count - grid.get_child_count()):
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		grid.add_child(line)
	for i in range(0, grid.get_child_count() - visible_record_count):
		_recycle_free_line(grid.get_child(-1))

	var field_count = fields.size()
	for line in grid.get_children():
		for f in range(0, field_count - line.get_child_count()):
			line.add_child(_get_cell_control_label())
		for f in range(0, line.get_child_count() - field_count):
			line.remove_child(line.get_child(-1))

	for r in range(visible_begin+1, visible_record_count + visible_begin + 1):
		var row = data.records[r]
		var linectnr = grid.get_child(r - (visible_begin+1))
		for f in range(0, row.size()):
			var celledit = linectnr.get_child(f)
			# Set cell edit
			_initialize_celledit(celledit)
			var content = row[f]
			if content is String:
				var n = content.find("\n")
				if n != -1:
					celledit.text = "%s…" % content.substr(0, n)
				else:
					celledit.text = content
			else:
				celledit.text = "%s" % content
			celledit.custom_minimum_size = Vector2(fields[f].width, cell_height)

# You can always call this after either creating a celledit or getting from a pool 
func _initialize_celledit(celledit: Label):
	celledit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	celledit.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	celledit.theme_type_variation = "TableCell"
	celledit.autowrap_mode = TextServer.AUTOWRAP_OFF
	celledit.clip_text = true
	celledit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	celledit.max_lines_visible = 1

func _recycle_free_line(line: HBoxContainer):
	for e in line.get_children():
		line.remove_child(e)
		if e is Label:
			_recycle_cell_control_label(e)
		else:
			e.queue_free()
	line.get_parent().remove_child(line)
	line.queue_free()

func _get_cell_control_label() -> Label:
	if _pool_label.get_child_count() == 0:
		return Label.new()
	var result = _pool_label.get_child(-1)
	_pool_label.remove_child(result)
	return result

func _recycle_cell_control_label(lb: Label):
	_pool_label.add_child(lb)
