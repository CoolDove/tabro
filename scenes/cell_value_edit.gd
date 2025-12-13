extends Control
class_name CellValueEdit

enum CellType { STRING }

@export var initial_value : Variant
@export var cell_type : CellType

var _editor : Control

var _canceled : bool

signal on_edit_finish(value)
signal on_edit_cancel

func close():
	queue_free()
	# var twn = create_tween()
	# twn.parallel().tween_property(self, "modulate", Color(1,1,1, 0), 0.1)
	# twn.parallel().tween_property(self, "size", Vector2(size.x,0), 0.15)
	# twn.tween_callback(queue_free)

func _init(value: Variant = null, type:CellType=CellType.STRING):
	self.initial_value = value
	self.cell_type = type

func _ready():
	match cell_type:
		CellType.STRING:
			var te = _create_text_edit()
			te.call_deferred("grab_focus")
			te.focus_exited.connect(func():
				if _canceled:
					return
				on_edit_finish.emit(te.text)
				te.focus_mode = Control.FOCUS_NONE
				te.editable = false
				close()
			)
			_editor = te

func _enter_tree():
	if _editor != null:
		_editor.call_deferred("grab_focus")

func _input(e):
	if e is InputEventMouseButton:
		if e.pressed:
			var lmpos = get_local_mouse_position()
			var safe = 5
			if lmpos.x < 0 - safe or lmpos.y < 0 - safe or lmpos.x >= size.x + safe or lmpos.y >= size.y + safe:
				_editor.release_focus()

func _create_text_edit() -> TextEdit:
	var te = TextEdit.new()
	if initial_value is String:
		te.text = initial_value
		te.set_caret_column(initial_value.length())
		te.clear_undo_history()
	te.set_anchors_preset(PRESET_FULL_RECT)
	add_child(te)
	te.call_deferred("grab_focus")
	var script = GDScript.new()
	script.source_code = """
extends TextEdit
signal gui_event_handle(e)
func _gui_input(e):
	gui_event_handle.emit(e)
"""

	script.reload()
	te.set_script(script)
	te.context_menu_enabled = false
	te.connect("gui_event_handle", func(e: InputEvent):
		if e is InputEventKey:
			if e.keycode == KEY_ESCAPE and e.pressed:
				_canceled = true
				on_edit_cancel.emit()
				close()
			elif e.keycode == KEY_ENTER and e.pressed:
				if not e.ctrl_pressed:
					te.release_focus()
	)
	return te
