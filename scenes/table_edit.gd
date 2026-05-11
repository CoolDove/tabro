extends Control
class_name TableEdit

var FieldLabelScn = preload("res://scenes/table_field_label.tscn")

@onready var titlescroller = %TitleScroller
@onready var titleline = %TitleLine
@onready var gridscroller = %ScrollContainer
@onready var grid = %Grid

var cell_value_edit : CellValueEdit

var data :TabroData:
	get:
		return _data
	set(v):
		_data = v
		v.normalize()
		call_deferred("refresh")
var _data : TabroData

var gutter_width :int= 46
var cell_height = 32.0
var fields :
	get:
		return data.fields if data != null else null

var _pool_label : Node # Array[Label]

var select_anchor : Vector2i # The first cell pressed in the select region.
var select_region : Rect2i # When size == Vector2i.ONE, means only one cell selected.
var hover_cell : Vector2i
var is_hover_cell_valid :bool:
	get:
		return is_cell_in_table_range(hover_cell.y, hover_cell.x)

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

var _filepath : String

# size should be "width x height", when you want to find [row, column], go row + column * height
# null  -> 脏，需要重新更新
# Node  -> 已经缓存的子节点，且和当前值对应，可以直接在_update_cell_value中设置
# 字符串 -> 已经缓存的用于直接显示的字符串，可以直接在_update_cell_value中设置
var _cell_backup : Array
func _refresh_cell_backup(size: int):
	_cell_backup.resize(size)
	for i in size:
		if _cell_backup[i] is Node: _cell_backup[i].queue_free()
		_cell_backup[i] = null
	print("refresh cell backup to size:	%s" % size)

func _find_cell_backup(row: int, column: int):
	var index :int= row + column * data.records.size()
	if _cell_backup.size() > index:
		return _cell_backup[index]
	else:
		return null

func _upload_cell_backup(row: int, column: int, value) -> bool:
	assert(value != null, "Dont do this! Use `_remove_cell_backup` instead.")
	var index :int= row + column * data.records.size()
	if _cell_backup.size() > index:
		_cell_backup[index] = value
		return true
	return false

func _remove_cell_backup(row: int, column: int):
	var index :int= row + column * data.records.size()
	if _cell_backup.size() > index:
		var value = _cell_backup[index] 
		if value is Node: value.queue_free()
		_cell_backup[index] = null

func _remove_cell_backup_by_column(column: int) -> bool:
	var current_table_size = data.fields.size() * data.records.size()
	if _cell_backup.size() != current_table_size:
		print("size doesn't match")
		return false
	var start :int= column * data.records.size()
	for i in range(start, start + data.records.size()):
		var value = _cell_backup[i]
		if value is Node: value.queue_free()
		_cell_backup[i] = null
	return true

static func load_from_data(tbrdata: TabroData) -> TableEdit:
	var _TableEdit = preload("./table_edit.tscn")
	var edit = _TableEdit.instantiate() as TableEdit
	edit.data = tbrdata
	return edit

static func load_from_file(filepath: String) -> TableEdit:
	if not FileAccess.file_exists(filepath):
		return null
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		return null
	var raw = file.get_as_text()
	file.close()
	var d = TabroData.deserialize(raw)
	if d != null and d is TabroData:
		var edit = load_from_data(d)
		edit._filepath = filepath
		return edit
	return null

func save(filepath:String=""):
	var saveto = filepath if filepath != "" else _filepath
	var file = FileAccess.open(saveto, FileAccess.WRITE)
	var jsonstr = TabroData.serialize(data)
	file.store_string(jsonstr)
	file.close()
	print("save to %s" % saveto)

func is_cell_in_table_range(row:int, column:int):
	return not (
		column < 0 or
		row < 0 or
		column >= fields.size() or
		row >= visible_end or
		row >= data.records.size()
	)

func _ready():
	# Add a little block to fit the scroll bar width in body scroll container.
	var gutter_spacing = Control.new()
	titleline.add_child(gutter_spacing, false, INTERNAL_MODE_FRONT)
	gutter_spacing.custom_minimum_size.x = gutter_width

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
		queue_refresh()
	)
	item_rect_changed.connect(queue_refresh)

	# For virtual spacing the table grid
	_virtual_spacing_before = Control.new()
	_virtual_spacing_before.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_virtual_spacing_before.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_virtual_spacing_after = Control.new()
	_virtual_spacing_after.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_virtual_spacing_after.size_flags_vertical = Control.SIZE_SHRINK_END

	var bottom_buttons = HBoxContainer.new()
	bottom_buttons.set_anchors_preset(PRESET_TOP_LEFT)
	_virtual_spacing_after.add_child(bottom_buttons)
	
	var btn_new_record = Button.new()
	btn_new_record.text = "Add New Record"
	btn_new_record.pressed.connect(func():
		data.add_record()
		queue_refresh()
		# refresh()
	)
	bottom_buttons.add_child(btn_new_record)

	var btn_manually_refresh = Button.new()
	btn_manually_refresh.text = "Manually Refresh"
	btn_manually_refresh.pressed.connect(func():
		queue_refresh()
	)
	bottom_buttons.add_child(btn_manually_refresh)

	grid.add_child(_virtual_spacing_before, false, INTERNAL_MODE_FRONT)
	grid.add_child(_virtual_spacing_after, false, INTERNAL_MODE_BACK)

	grid.draw.connect(func ():
		if data == null:
			return
		var grid_size = grid.size
		var grid_color = Color.BLACK

		grid.draw_line(Vector2(0,0), Vector2(grid_size.x, 0), grid_color)
		for i in range(visible_begin, min(visible_end, data.records.size())):
			var y = (i + 1) * cell_height
			grid.draw_line(Vector2(0,y), Vector2(grid_size.x, y), grid_color)
		var x = 0
		var bottom = min(grid_size.y, data.records.size() * cell_height)
		var draw_hover_cell = null
		grid.draw_line(Vector2(x + gutter_width, 0), Vector2(x + gutter_width, bottom), grid_color)
		for fidx in range(0, fields.size()):
			var f = fields[fidx]
			if is_hover_cell_valid and hover_cell.x == fidx:
				draw_hover_cell = Rect2(Vector2(x + gutter_width, hover_cell.y * cell_height), Vector2(f.width, cell_height));
			x += f.width
			grid.draw_line(Vector2(x + gutter_width, 0), Vector2(x + gutter_width, bottom), grid_color)
		if select_region.position.x >= 0 && select_region.position.y >= 0:
			# draw the select region
			var p = select_region.position
			var s = select_region.size
			var xmin = 0
			var width = 0
			for i in range(0, p.x):
				var w = fields[i].width
				xmin += w
			for i in range(p.x, p.x+s.x+1):
				var w = fields[i].width
				width += w
			var select_rect = Rect2i(\
				Vector2i(Vector2(xmin + gutter_width, p.y*cell_height)),\
				Vector2i(width, (s.y + 1)*cell_height))
			grid.draw_rect(select_rect, Color(0x22afa222), true)
			grid.draw_rect(select_rect, Color(0x22afa255), false, 2)

		if draw_hover_cell is Rect2:
			grid.draw_rect(draw_hover_cell, Color(0x00c2c1ff), false, 3)
	)
	if data != null:
		queue_refresh()

func _enter_tree():
	_pool_label = Node.new()

func _exit_tree():
	_pool_label.queue_free()

func _gui_input(event):
	if event is InputEventMouseMotion:
		_update_hover()
		if event.button_mask & MouseButton.MOUSE_BUTTON_LEFT && is_hover_cell_valid:
			var region := Rect2i(select_anchor, Vector2i.ZERO)
			if hover_cell.x < select_anchor.x:
				region.position.x = hover_cell.x
				region.size.x = select_anchor.x - hover_cell.x
			elif hover_cell.x > select_anchor.x:
				region.size.x = hover_cell.x - select_anchor.x
			if hover_cell.y < select_anchor.y:
				region.position.y = hover_cell.y
				region.size.y = select_anchor.y - hover_cell.y
			elif hover_cell.y > select_anchor.y:
				region.size.y = hover_cell.y - select_anchor.y
			_update_select(region)
	elif event is InputEventMouseButton:
		if Input.is_key_pressed(KEY_CTRL):
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					var th = Main.instance.theme
					th.default_font_size = min(th.default_font_size + 1, 64)
					queue_refresh()
				MOUSE_BUTTON_WHEEL_DOWN:
					var th = Main.instance.theme
					th.default_font_size = max(th.default_font_size - 1, 12)
					queue_refresh()
		else:
			match event.button_index:
				MOUSE_BUTTON_LEFT:
					_update_hover()
					if is_hover_cell_valid:
						if event.is_pressed():
							select_anchor = hover_cell
							_update_select(Rect2i(hover_cell, Vector2i.ZERO))
						else:
							_open_cell_edit(hover_cell.y, hover_cell.x)
				MOUSE_BUTTON_RIGHT:
					_update_hover()
					if is_hover_cell_valid:
						# open context menu on cell
						pass
		_update_hover()

var _watch_mem_interval : float
var _watch_mem_pool_count : int
var _watch_mem_pool_count_last : int
var _watch_mem_pool_target : int
func _process(delta):
	var current_table_size = data.fields.size() * data.records.size()
	if _cell_backup.size() != current_table_size:
		_refresh_cell_backup(current_table_size)

	if _debug_update_cell_value_count_inframe > 0:
		print("update cells in frame: %s" % _debug_update_cell_value_count_inframe)
		_debug_update_cell_value_count_inframe = 0
	if _debug_cell_backup_hit > 0:
		print("cell backup hit in frame: %s" % _debug_cell_backup_hit)
		_debug_cell_backup_hit = 0

	if _refresh_queued:
		refresh()
		_refresh_queued = false

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
	grid_mpos.x -= gutter_width
	var new_hover_cell
	var is_outside = grid_mpos.x < 0 or grid_mpos.y < 0 or grid_mpos.x > gridscroller.size.x or grid_mpos.y > gridscroller.size.y
	if is_outside: # or cell_value_edit != null:
		new_hover_cell = Vector2i(-1,-1)
	else:
		var hovery = floori((grid_mpos.y + gridscroller.scroll_vertical) / cell_height)
		var _hoverxpx = int(grid_mpos.x + gridscroller.scroll_horizontal)
		var hoverx = -1
		for fieldidx in range(0, fields.size()):
			hoverx = fieldidx
			var field = fields[fieldidx]
			if _hoverxpx < field.width:
				_hoverxpx = 0
				break
			_hoverxpx -= field.width
		if _hoverxpx > 0:
			hoverx = fields.size()
		new_hover_cell = Vector2i(hoverx, hovery)
	if new_hover_cell == hover_cell:
		return
	if hover_cell != new_hover_cell:
		queue_redraw()
	hover_cell = new_hover_cell
	grid.queue_redraw()

func _update_select(new_select_region: Rect2i):
	print("select %s" % [new_select_region])
	select_region = new_select_region
	grid.queue_redraw()

func _open_cell_edit(row: int, column: int):
	print("open cell edit on : %s, %s" % [row, column])
	var cell_control = _try_get_cellctrl(column, row)
	# To instantiate the quick cell value editor.
	var fieldinfo = fields[column]
	if cell_control != null:
		if fieldinfo.type == Main.FieldType.OPTION:
			var editor = ResourceLoader.load("res://scenes/cell_value_editor/cell_value_editor_option.tscn").instantiate()
			editor.data = data
			editor.fieldinfo = fieldinfo
			editor.row = row
			editor.column = column
			add_child(editor)
			editor.size = Vector2(fieldinfo.width+1, cell_height+1)
			editor.global_position = cell_control.global_position + Vector2(-1, -1)
			for o in fieldinfo.toption_options: editor.add_item(o)
			editor.on_value_changed.connect(func(value):
				data.records[row][column] = value
				_remove_cell_backup(row, column)
				queue_refresh()
			)
			editor.on_exit_code.connect(func(code:CellValueEditorStatic.ExitCode):
				var rn :int = row
				var cn :int = column
				match code:
					CellValueEditorStatic.ExitCode.Enter:
						rn = row+1
					CellValueEditorStatic.ExitCode.SEnter:
						rn = row-1
					CellValueEditorStatic.ExitCode.Tab:
						cn = column+1
					CellValueEditorStatic.ExitCode.STab:
						cn = column-1
				print("new position: %s, %s" % [rn, cn] )
				if (rn != row or cn != column) and is_cell_in_table_range(rn, cn):
					call_deferred("_update_select", Rect2i(cn, rn, 0,0))
					call_deferred("_open_cell_edit", rn, cn)
			)
		else:
			var editor = ResourceLoader.load("res://scenes/cell_value_editor/cell_value_editor.tscn").instantiate() as LineEdit
			add_child(editor)
			editor.set_deferred("size", Vector2(fieldinfo.width+1, cell_height+1))
			editor.global_position = cell_control.global_position + Vector2(-1, -1)
			var celldata = data.records[row][column]
			editor.text = "%s" % celldata if celldata != null else ""
			editor.text_changed.connect(func(text:String):
				data.records[row][column] = text
				_remove_cell_backup(row, column)
				queue_refresh()
			)
			editor.on_exit_code.connect(func(code:CellValueEditorStatic.ExitCode):
				var rn :int = row
				var cn :int = column
				match code:
					CellValueEditorStatic.ExitCode.Enter:
						rn = row+1
					CellValueEditorStatic.ExitCode.SEnter:
						rn = row-1
					CellValueEditorStatic.ExitCode.Tab:
						cn = column+1
					CellValueEditorStatic.ExitCode.STab:
						cn = column-1
				print("new position: %s, %s" % [rn, cn] )
				if (rn != row or cn != column) and is_cell_in_table_range(rn, cn):
					call_deferred("_update_select", Rect2i(cn, rn, 0,0))
					call_deferred("_open_cell_edit", rn, cn)
			)

func _try_get_cellctrl(column: int, row: int, cached_linectnr: Control=null) -> Control:
	if data == null:
		return null
	if column < 0 or row < 0 or row > data.records.size() - 1 or column > fields.size() - 1:
		return null
	var linectnr = _try_get_line_ctnr(row)
	if linectnr == null:
		return null
	return linectnr.get_child(column) as Control

func _try_get_line_ctnr(row: int) -> Control:
	if row >= visible_begin and row < visible_end and row < data.records.size():
		return grid.get_child(row - visible_begin)
	return null

func _convert_field_type(column: int, from_type: Main.FieldType, to_type: Main.FieldType):
	var fieldinfo = data.fields[column]
	for record in data.records:
		var cell = record[column]
		var plain_text :String
		if from_type == Main.FieldType.OPTION:
			if cell is Array[int]:
				plain_text = ",".join(cell.map(func (fromv)->String: return fieldinfo.toption_options[fromv]) as PackedStringArray)
			else:
				plain_text = ""
		else:
			plain_text = ("%s" % cell) if cell != null else ""
		# print("convert to plain text: %s" % plain_text)
		if to_type == Main.FieldType.OPTION:
			if plain_text != null && plain_text != "":
				var elems = CsvReader.parse_csv_line(plain_text)
				var elemids :Array[int]
				fieldinfo.toption_multiple = true
				for e in elems:
					if e == "":
						continue
					var find :int= fieldinfo.toption_options.find(e)
					if find > -1:
						elemids.append(find)
					else:
						elemids.append(fieldinfo.toption_options.size())
						fieldinfo.toption_options.append(e)
				record[column] = elemids
		elif to_type == Main.FieldType.STRING:
			record[column] = plain_text

	_remove_cell_backup_by_column(column)
	queue_refresh()
	#for r in range(visible_begin, visible_end):
		#var linectnr = _try_get_line_ctnr(r)
		#if linectnr != null:
			#var cellctrl = linectnr.get_child(column)
			#if cellctrl != null:
				#_update_cell_value(cellctrl, column, r, data.records[r][column])

var _refresh_queued :bool= true
func queue_refresh():
	_refresh_queued = true

func refresh():
	if data == null:
		return

	var th = Main.instance.theme
	cell_height = max(th.default_font.get_height(th.default_font_size) + 12, 28)

	grid.custom_minimum_size.y = cell_height * data.records.size()

	_virtual_spacing_before.custom_minimum_size = Vector2(0, visible_begin * cell_height)
	_virtual_spacing_after.custom_minimum_size  = Vector2(0, int(gridscroller.size.y * 0.4))

	var fields_count = fields.size()
	for i in range(0, fields_count - titleline.get_child_count()):
		var field_label = FieldLabelScn.instantiate()
		titleline.add_child(field_label)
		field_label.on_left_release.connect(func():
			var field_index = field_label.get_meta("field_index")
			var field = fields[field_index]
			# You can add_child to this inspector.
			# But maybe not for a normal value cell.
			var root = Main.request_inspector()
			var inspector = Main.instance.pks_field_inspector.instantiate() as Control
			root.add_child(inspector)
			inspector.fieldinfo = field
			inspector.field_name = field.name
			inspector.field_type = field.type
			inspector.set_anchors_preset(PRESET_FULL_RECT)
			inspector.on_field_type_changed.connect(func(type:Main.FieldType):
				field.type = type
				var old_type :Main.FieldType= field_label.field_type
				field_label.field_type = field.type
				_convert_field_type(field_index, old_type, field.type)
			)
			inspector.on_field_option_changed.connect(func():
				for r in range(visible_begin, visible_end):
					var cellctrl = _try_get_cellctrl(field_index, r)
					if cellctrl != null:
						_update_cell_value(cellctrl, field_index, r, data.records[r][field_index])
			)
		)

	for i in range(0, titleline.get_child_count() - fields_count):
		var c = titleline.get_child(-1)
		titleline.remove_child(c)
		c.queue_free()

	for fidx in range(0, fields_count):
		var field = fields[fidx]
		var cellctrl = titleline.get_child(fidx)
		# Set field edit
		_initialize_cellctrl(cellctrl)
		cellctrl.text = field.name
		cellctrl.custom_minimum_size = Vector2(field.width, cell_height + 4)
		cellctrl.on_width_changed.connect(func(width: float):
			field.width = width
			for record in grid.get_children():
				var cell = record.get_child(fidx)
				cell.custom_minimum_size.x = field.width
		)
		cellctrl.field_type = field.type
		cellctrl.set_meta("field_index", fidx)
		#print("refresh field label: %s of type %s" % [field.name, field.type])

	var visible_record_count = min(\
			visible_end - visible_begin, data.records.size() - visible_begin
	)
	for i in range(0, visible_record_count - grid.get_child_count()):
		var line = HBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		grid.add_child(line)
		var gutter :Label= Label.new()
		line.add_child(gutter, false, Node.INTERNAL_MODE_FRONT)
		gutter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gutter.custom_minimum_size.x = gutter_width
		gutter.add_theme_color_override("font_color", Color.DARK_GRAY)
	for i in range(0, grid.get_child_count() - visible_record_count):
		_recycle_free_line(grid.get_child(-1))

	var field_count = fields.size()
	for line in grid.get_children():
		for f in range(0, field_count - line.get_child_count()):
			line.add_child(_get_cell_control_label())
		for f in range(0, line.get_child_count() - field_count):
			line.remove_child(line.get_child(-1))

	for r in range(visible_begin, visible_record_count + visible_begin):
		var rowdata = data.records[r]
		var linectnr = grid.get_child(r - visible_begin)
		var gutter :Label= linectnr.get_child(0, true)
		gutter.text = "%s" % r
		for col in range(0, fields_count):
			var cellctrl = linectnr.get_child(col)
			# Set cell edit
			_initialize_cellctrl(cellctrl)
			cellctrl.custom_minimum_size = Vector2(fields[col].width, cell_height)
			_update_cell_value(cellctrl, col, r, rowdata[col])
	grid.queue_redraw()

var _debug_update_cell_value_count_inframe :int
var _debug_cell_backup_hit :int
func _update_cell_value(control: Control, column: int, row: int, celldata):
	# print("update cell value of: [row: %s, column: %s]" % [column, row])
	var fieldinfo = fields[column]
	# Remove the children, some complex types add children to show things, like multi-option type.
	for c in control.get_children(): control.remove_child(c)

	var backup = _find_cell_backup(row, column)
	if backup != null:
		if backup is String:
			control.set("text", backup)
			_debug_cell_backup_hit += 1
			return
		elif backup is Node:
			if backup.get_parent() != null:
				backup.reparent(control, false)
			else:
				control.add_child(backup)
			control.text = ""
			_debug_cell_backup_hit += 1
			return
		else:
			print("unknown cell backup type: %s" % backup)

	if fieldinfo.type == Main.FieldType.STRING:
		var value :String= celldata if celldata is String else ""
		control.set("text", value)
		# control.add_theme_color_override("font_color", Color.BLACK)
		_upload_cell_backup(row, column, value)
	elif fieldinfo.type == Main.FieldType.NUMBER:
		var data :String= celldata if celldata is String else ""
		if data == "":
			control.set("text", "")
		else:
			var is_int :bool= fieldinfo.tnumber_type == FieldData.NumberType.Integer
			var is_float :bool= fieldinfo.tnumber_type == FieldData.NumberType.Float
			var type_match :bool= \
				(is_int && data.is_valid_int()) || \
				(is_float && data.is_valid_float())
			if type_match:
				var value :String= "%s" % data.to_int() if is_int else (data.to_float() if is_float else "Unknown Number Type")
				control.set("text", value)
				# control.add_theme_color_override("font_color", Color.DARK_GREEN)
				_upload_cell_backup(row, column, value)
	elif fieldinfo.type == Main.FieldType.OPTION:
		var valid = true
		if celldata is not Array[int]:
			valid = false
		if valid:
			var options :Array[int]= celldata
			var scroll_ctnr = ScrollContainer.new()
			scroll_ctnr.set_anchors_preset(PRESET_FULL_RECT)
			control.add_child(scroll_ctnr)
			var ctnr = HBoxContainer.new()
			ctnr.set_anchors_preset(PRESET_FULL_RECT)
			ctnr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			scroll_ctnr.add_child(ctnr)
			ctnr.custom_minimum_size.y = scroll_ctnr.size.y
			scroll_ctnr.item_rect_changed.connect(func():
				ctnr.custom_minimum_size.y = scroll_ctnr.size.y
			)
			for elem in options:
				var lb = ResourceLoader.load("res://scenes/option_element.tscn").instantiate()
				var text :String= fieldinfo.toption_options[elem]
				lb.text = text
				var h = (rand_from_seed(lb.text.hash())[0]%128)/128.0
				lb.set_deferred("color", Color.from_hsv(h, 0.7, 0.6))
				ctnr.add_child(lb)
			control.set("text", "")
			_upload_cell_backup(row, column, scroll_ctnr)
		#else:
			#control.set("text", "???(%s)" % celldata)
			#control.add_theme_color_override("font_color", Color(1,0,0,0.2))
	elif fieldinfo.type == Main.FieldType.CODE:
		var script = GDScript.new()
		script.source_code = fieldinfo.tcode_code
		#TODO: Cache this script.
		var err = script.reload()
		var ok = false
		if err == 0:
			var process_func = script.get_script_method_list().find_custom(
				func(v): return v["name"] == "process_value"
			)
			if process_func > -1:
				var result = script.call("process_value", "" if celldata == null || typeof(celldata) != TYPE_STRING else celldata)
				control.set("text", result)
				# control.add_theme_color_override("font_color", Color.DARK_CYAN)
				ok = true
				_upload_cell_backup(row, column, result)
		else:
			print("Script compile error: %s" % err)

		if not ok:
			control.set("text", celldata)
			# control.add_theme_color_override("font_color", Color.DARK_CYAN)
	else:
		control.set("text", celldata)
		# control.add_theme_color_override("font_color", Color.BLACK)
	_debug_update_cell_value_count_inframe += 1

# You can always call this after either creating a cellctrl or getting from a pool 
func _initialize_cellctrl(cellctrl: Label):
	if cellctrl == null:
		return
	cellctrl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cellctrl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cellctrl.theme_type_variation = "TableCell"
	cellctrl.autowrap_mode = TextServer.AUTOWRAP_OFF
	cellctrl.clip_text = false # For batch text rendering
	cellctrl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cellctrl.max_lines_visible = 1

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
