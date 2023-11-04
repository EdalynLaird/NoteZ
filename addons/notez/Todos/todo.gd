@tool
extends PanelContainer
class_name NotezTodo

signal changed(new_dict: Dictionary)
signal delete

const SCENE : PackedScene = preload("res://addons/notez/Todos/todo.tscn")
const TAG_MANAGER = preload("res://addons/notez/tag_manager.tscn")

var tags : PackedStringArray
var progress_log : String

@onready var progress_log_window : Window = $ProgessLogWindow

static func new_from_dict(data: Dictionary) -> NotezTodo:
	var temp := SCENE.instantiate() as NotezTodo
	temp.from_dict(data)
	
	return temp

func _ready():
	$HB/CB.pressed.connect(update)
	$HB/ProgressLog.pressed.connect(func():
		progress_log_window.get_node("TE").text = progress_log
		progress_log_window.show()
		)
	progress_log_window.close_requested.connect(func():
		progress_log = progress_log_window.get_node("TE").text
		progress_log_window.hide()
		changed.emit(to_dict())
		)
	$HB/Tags.pressed.connect(func():
		var temp = TAG_MANAGER.instantiate()
		add_child(temp)
		temp.setup(NotezAutoload.todo_tags, tags)
		temp.new_tags.connect(func(new_tags):
			print(new_tags)
			tags = new_tags
			temp.queue_free()
			update()
			)
		)
	$HB/More.get_popup().id_pressed.connect(func(id: int):
		match id:
			0:
				delete.emit()
			1:
				NotezAutoload.recall_todo(name)
		)

## the dictionary will look like this:
##	{
##		"checked" : bool
##		"name" : String
##		"tags" : PackedStringArray
##		"Progress Log" : String
##	}
func to_dict() -> Dictionary:
	return {
		"checked" : $HB/CB.button_pressed,
		"name" : $HB/Name.text,
		"tags" : tags,
		"Progress Log" : progress_log,
	}

func from_dict(data: Dictionary) -> void:
	$HB/CB.button_pressed = data.get("checked", false)
	$HB/Name.text = data.get("name", "!NAME NOT PROVIDED!")
	name = $HB/Name.text
	tags = data.get("tags", [])
	progress_log = data.get("Progress Log", "")

func update():
	changed.emit(to_dict())
