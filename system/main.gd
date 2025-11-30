extends Control
class_name Main

@onready var menu = $Window/MenuBar
@onready var popupm_file = $Window/MenuBar/PM_File
@onready var popupm_edit = $Window/MenuBar/PM_Edit
@onready var main_panel = $Window/Body/MainPanel

static var instance : Main

func _ready():
	instance = self
	popupm_file.id_pressed.connect(func(id):
		match id:
			0:
				action_open_file()
			1:
				var table_edit = main_panel.get_child(0)
				if table_edit == null or table_edit is not TableEdit:
					return
				var saveto = table_edit._filepath
				if saveto == null or saveto == "":
					var fdialog = FileDialog.new()
					fdialog.mode = Window.MODE_WINDOWED
					fdialog.use_native_dialog = true
					fdialog.access = FileDialog.ACCESS_FILESYSTEM
					fdialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
					fdialog.filters = ["*.tbr"]
					fdialog.file_selected.connect(func(file):
						print("save file to: %s" % file)
						table_edit.save(file)
						table_edit._filepath = file
						fdialog.queue_free()
					)
					fdialog.canceled.connect(fdialog.queue_free)
					add_child(fdialog)
					fdialog.popup_centered_ratio()
				else:
					table_edit.save(saveto)
					table_edit._filepath = saveto
			2:
				var table_edit = main_panel.get_child(0)
				if table_edit == null or table_edit is not TableEdit:
					return
				var fdialog = FileDialog.new()
				fdialog.mode = Window.MODE_WINDOWED
				fdialog.use_native_dialog = true
				fdialog.access = FileDialog.ACCESS_FILESYSTEM
				fdialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
				fdialog.filters = ["*.tbr"]
				fdialog.file_selected.connect(func(file):
					print("save file to: %s" % file)
					table_edit.save(file)
					table_edit._filepath = file
					fdialog.queue_free()
				)
				fdialog.canceled.connect(fdialog.queue_free)
				add_child(fdialog)
				fdialog.popup_centered_ratio()
			3:
				for c in main_panel.get_children():
					c.queue_free()
	)
	var font = SystemFont.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_LCD
	font.font_names = ["Verdana", "Cambria"]
	theme = ThemeDB.get_project_theme()
	theme.default_font = font
	theme.default_font_size = 22

	await get_tree().process_frame

	var empty_table = TabroData.new()
	empty_table.normalize()
	empty_table.add_field("id")
	empty_table.add_field("name")
	empty_table.add_field("description")
	empty_table.add_record()
	empty_table.add_record()
	empty_table.add_record()
	_open_data(empty_table)

func action_open_file():
	var fdialog = FileDialog.new()
	fdialog.mode = Window.MODE_WINDOWED
	fdialog.use_native_dialog = true
	fdialog.access = FileDialog.ACCESS_FILESYSTEM
	fdialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fdialog.filters = ["*.tbr"]

	fdialog.file_selected.connect(func(file):
		print("select file: %s" % file)
		open_file(file)
		fdialog.queue_free()
	)
	fdialog.canceled.connect(fdialog.queue_free)

	add_child(fdialog)
	fdialog.popup_centered_ratio()

func clear_main_panel():
	for c in main_panel.get_children():
		c.queue_free()
func add_to_main_panel(control: Control):
	control.set_anchors_preset(PRESET_FULL_RECT)
	main_panel.add_child(control)

func open_file(filepath: String) -> bool:
	if not FileAccess.file_exists(filepath):
		return false
	clear_main_panel()
	var table_edit = TableEdit.load_from_file(filepath)
	if table_edit == null:
		return false
	add_to_main_panel(table_edit)
	return true

func _open_data(data: TabroData) -> bool:
	clear_main_panel()
	var table_edit = TableEdit.load_from_data(data)
	if table_edit == null:
		return false
	add_to_main_panel(table_edit)
	return true
