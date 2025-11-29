extends Control

@onready var menu = $Window/MenuBar
@onready var popupm_file = $Window/MenuBar/PM_File
@onready var popupm_edit = $Window/MenuBar/PM_Edit
@onready var main_panel = $Window/Body/MainPanel

var _TableEdit = preload("res://scenes/table_edit.tscn")

func _ready():
	popupm_file.id_pressed.connect(func(id):
		match id:
			0:
				action_open_file()
			1:
				print("Not implemented!")
	)


func action_open_file():
	var fdialog = FileDialog.new()
	fdialog.mode = Window.MODE_WINDOWED
	fdialog.use_native_dialog = true
	fdialog.access = FileDialog.ACCESS_FILESYSTEM
	fdialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fdialog.filters = ["*.csv"]

	fdialog.file_selected.connect(func(file):
		print("select file: %s" % file)
		var csvdata = CsvReader.load(file)
		for c in main_panel.get_children():
			c.queue_free()
		var table_edit = _TableEdit.instantiate() as TableEdit
		table_edit.data = csvdata
		table_edit.set_anchors_preset(PRESET_FULL_RECT)
		main_panel.add_child(table_edit)
	)

	add_child(fdialog)
	fdialog.popup_centered_ratio()
# Some useless code
# func _show_menu_at_mouse_pos():
# 	NativeMenu.popup(menu, DisplayServer.mouse_get_position())
# 
# func _menu_callable(id):
# 	if id == "MENU_OPEN":
# 		print("press open")
# 	if id == "MENU_SAVE":
# 		print("press save")
# 
# func _enter_tree():
# 	menu = NativeMenu.create_menu()
# 	NativeMenu.add_item(menu, "Open", _menu_callable, Callable(), "MENU_OPEN")
# 	NativeMenu.add_item(menu, "Save", _menu_callable, Callable(), "MENU_SAVE")
# 
# func _exit_tree():
# 	NativeMenu.free_menu(menu)
