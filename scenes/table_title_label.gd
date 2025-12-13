@tool
extends Label
class_name TableTitleLabel

var resize_dragger : Control

signal on_width_changed(width: float)

func _ready():
	resize_dragger = ColorRect.new()
	resize_dragger.color = Color.GREEN
	add_child(resize_dragger, false, INTERNAL_MODE_BACK)
	resize_dragger.set_anchors_preset(PRESET_RIGHT_WIDE)
	resize_dragger.offset_left = -10
	resize_dragger.offset_bottom = 0
	resize_dragger.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	resize_dragger.gui_input.connect(_resize_dragger_gui_input)

func _resize_dragger_gui_input(e: InputEvent):
	if e is InputEventMouseMotion:
		if e.button_mask & MouseButton.MOUSE_BUTTON_LEFT:
			var lmpos = get_local_mouse_position()
			var new_width = clamp(lmpos.x, 120, 300)
			custom_minimum_size.x = new_width
			on_width_changed.emit(new_width)
