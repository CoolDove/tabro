@tool
extends Label
class_name FieldLabel

var resize_dragger : Control

@onready var type_icon = %Icon

signal on_width_changed(width: float)
signal on_left_press
signal on_right_press
signal on_left_release
signal on_right_release

var _hovering_on_drag = false

var _ICONS = [
	preload("res://resources/icons/field_type_string.tres"),
	preload("res://resources/icons/field_type_option.tres"),
	preload("res://resources/icons/field_type_number.tres"),
	preload("res://resources/icons/field_type_code.tres"),
	preload("res://resources/icons/field_type_unknown.tres"),
]

var field_type :Main.FieldType:
	set(value):
		field_type = value
		type_icon.texture = _ICONS[value]

func _ready():
	print("ready")
	resize_dragger = Control.new()
	resize_dragger.name = "ResizeDragger"
	# resize_dragger.color = Color.GREEN
	add_child(resize_dragger, false, INTERNAL_MODE_BACK)
	resize_dragger.mouse_filter = Control.MOUSE_FILTER_PASS
	resize_dragger.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	resize_dragger.gui_input.connect(_resize_dragger_gui_input)
	resize_dragger.mouse_entered.connect(_on_enter_dragger)
	resize_dragger.mouse_exited.connect(_on_exit_dragger)
	resize_dragger.set_anchors_preset(PRESET_RIGHT_WIDE)
	resize_dragger.offset_left   = -10
	resize_dragger.offset_right  = 0
	resize_dragger.offset_bottom = 0
	resize_dragger.offset_top    = 0

func _resize_dragger_gui_input(e: InputEvent):
	if e is InputEventMouseMotion:
		if e.button_mask & MouseButton.MOUSE_BUTTON_LEFT:
			var lmpos = get_local_mouse_position()
			var new_width = clamp(lmpos.x, 120, 300)
			custom_minimum_size.x = new_width
			on_width_changed.emit(new_width)

func _gui_input(e):
	if e is InputEventMouseButton:
		if e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				on_left_press.emit()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				on_right_press.emit()
		else:
			if e.button_index == MOUSE_BUTTON_LEFT:
				on_left_release.emit()
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				on_right_release.emit()

func _draw():
	var rect = get_rect()
	draw_line(Vector2(rect.size.x, 0), Vector2(rect.size.x, rect.size.y), Color.BLACK, 4 if _hovering_on_drag else 2)

func _on_enter_dragger():
	_hovering_on_drag = true
	queue_redraw()

func _on_exit_dragger():
	_hovering_on_drag = false
	queue_redraw()
