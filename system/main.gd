extends Control
class_name Main

@onready var menu = $Window/MenuBar
@onready var popupm_file = $Window/MenuBar/PM_File
@onready var popupm_edit = $Window/MenuBar/PM_Edit
@onready var main_panel = $Window/Body/MainPanel

var _TableEdit = preload("res://scenes/table_edit.tscn")

static var instance : Main

func _ready():
	instance = self
	popupm_file.id_pressed.connect(func(id):
		match id:
			0:
				action_open_file()
			1:
				print("Not implemented!")
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
	open_file("res://resources/skills.csv")

func action_open_file():
	var fdialog = FileDialog.new()
	fdialog.mode = Window.MODE_WINDOWED
	fdialog.use_native_dialog = true
	fdialog.access = FileDialog.ACCESS_FILESYSTEM
	fdialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fdialog.filters = ["*.csv"]

	fdialog.file_selected.connect(func(file):
		print("select file: %s" % file)
		open_file(file)
		fdialog.queue_free()
	)
	fdialog.canceled.connect(fdialog.queue_free)

	add_child(fdialog)
	fdialog.popup_centered_ratio()

func open_file(filepath: String):
	var csvdata = CsvReader.load(filepath)
	for c in main_panel.get_children():
		c.queue_free()
	var table_edit = _TableEdit.instantiate() as TableEdit
	table_edit.data = csvdata
	table_edit.set_anchors_preset(PRESET_FULL_RECT)
	main_panel.add_child(table_edit)
