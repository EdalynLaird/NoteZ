@tool
extends HBoxContainer

var tracking_mouse: bool

func _ready():
	$T.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.pressed && event.button_index == MOUSE_BUTTON_LEFT:
				tracking_mouse = true
			elif !event.pressed:
				tracking_mouse = false
		)

func _process(delta):
	if tracking_mouse:
		global_position.y = get_global_mouse_position().y
		position.y = clamp(position.y, 0, get_parent().size.y - size.y)
