@tool
extends PanelContainer

var curr_scene : Node
var old_text : String

var checked_out_todos : Dictionary # "name" : todo(Node)

@onready var todo_container : VBoxContainer = $VSP/Todos

@onready var save_button : Button = $VSP/Text/PC/Controls/Save
@onready var reject_button : Button = $VSP/Text/PC/Controls/Reject
@onready var edit_button : Button = $VSP/Text/PC/Controls/Edit
@onready var create_button : Button = $VSP/Text/PC/Controls/Create
@onready var refresh_button : Button = $VSP/Text/PC/Controls/Referesh
@onready var delete_button : Button = $VSP/Text/PC/Controls/Delete

@onready var edit : TextEdit = $VSP/Text/Container/TextEdit
@onready var label : RichTextLabel = $VSP/Text/Container/RichTextLabel

func _ready():
	var color_select : ColorPickerButton = $VSP/Text/PC/Controls/BackgroundColor
	color_select.color_changed.connect(func(color: Color):
		theme.get_stylebox("panel", "PanelContainer").bg_color = color
		)
	for i in NotezAutoload.COLORS:
		color_select.get_picker().add_preset(i)
	
	create_button.pressed.connect(create)
	save_button.pressed.connect(edit_to_label.bind(true))
	reject_button.pressed.connect(edit_to_label.bind(false))
	edit_button.pressed.connect(label_to_edit)
	
	NotezAutoload.save.connect(save)
	
	

func chenge_scene(scene: Node):
	save()
	
	if !scene || !FileAccess.file_exists(scene.scene_file_path):
		to_invalid_scene()
		return
	if !FileAccess.file_exists(scene_file_to_note_file(scene.scene_file_path)):
		to_empty_note()
		return
	curr_scene = scene
	
	open()
	edit_to_label(true)

func save():
	if label.visible:
		label_to_edit()
	
	if !curr_scene || !curr_scene.scene_file_path:
		return
	
	var todos := []
	for i in todo_container.todo_container.get_children():
		todos.append(i.name)
	var data := {
		"text" : edit.text,
		"todos" : todos,
		"color" : $VSP/Text/PC.get_theme_stylebox("panel").bg_color.to_html()
	}
	var file = FileAccess.open(scene_file_to_note_file(curr_scene.scene_file_path), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func open():
	var data = JSON.new()
	var file = FileAccess.open(scene_file_to_note_file(curr_scene.scene_file_path), FileAccess.READ)
	var error = data.parse(file.get_as_text())
	file.close()
	
	edit.text = data.data.get("text", "")
	$VSP/Text/PC.get_theme_stylebox("panel").bg_color = Color(data.data.get("color", "#000000"))
	
	todo_container.clear_todos()
	for i in data.data.get("todos", []):
		todo_container.check_out_todo(i)

func refresh():
	if !curr_scene:
		return
	if FileAccess.file_exists(curr_scene.scene_file_path):
		to_empty_note()

func create():
	save_button.hide()
	reject_button.hide()
	edit_button.show()
	create_button.hide()
	refresh_button.hide()
	
	label.show()
	edit.hide()
	
	if !curr_scene:
		return
	var path = scene_file_to_note_file(curr_scene.scene_file_path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\n}")
	file.close()

func edit_to_label(save: bool):
	save_button.hide()
	reject_button.hide()
	edit_button.show()
	create_button.hide()
	refresh_button.hide()
	delete_button.show()
	
	label.show()
	edit.hide()

	if save:
		label.text = edit.text
	else:
		label.text = old_text

func label_to_edit():
	save_button.show()
	reject_button.show()
	edit_button.hide()
	create_button.hide()
	refresh_button.hide()
	delete_button.show()
	
	label.hide()
	edit.show()
	
	edit.text = label.text
	old_text = label.text

func to_empty_note():
	save_button.hide()
	reject_button.hide()
	edit_button.hide()
	create_button.show()
	refresh_button.hide()
	delete_button.hide()
	
	label.hide()
	edit.show()
	
	label.text = ""
	old_text = ""
	edit.text = ""

func to_invalid_scene():
	save_button.hide()
	reject_button.hide()
	edit_button.hide()
	create_button.hide()
	refresh_button.show()
	delete_button.hide()
	
	label.show()
	edit.hide()
	
	label.text = ""
	old_text = ""
	edit.text = ""

func scene_file_to_note_file(path: String) -> String:
	path = path.trim_prefix("res://")
	path = path.trim_suffix(".tscn")
	path = path.replace("/", "-")
	path = "res://.Notez/" + path + ".json"

	return path

#
#var active_path : String
#var active_scene : Node
#var checked_out_todos : Dictionary
#
#var old_text : String
#
#@onready var todo_container : VBoxContainer = $VSP/Todos/ScrollContainer/TodoContainer
#
#@onready var save_button : Button = $VSP/Text/PC/Controls/Save
#@onready var reject_button : Button = $VSP/Text/PC/Controls/Reject
#@onready var edit_button : Button = $VSP/Text/PC/Controls/Edit
#@onready var create_button : Button = $VSP/Text/PC/Controls/Create
#
#@onready var edit : TextEdit = $VSP/Text/Container/TextEdit
#@onready var label : RichTextLabel = $VSP/Text/Container/RichTextLabel
#
#func _ready():
#	$VSP/Text/PC/Controls/BackgroundColor.color_changed.connect(func(color: Color):
#		$VSP/Text/PC.get_theme_stylebox("panel").bg_color = color
#		)
#
#	create_button.pressed.connect(create)
#	save_button.pressed.connect(edit_to_label.bind(true))
#	reject_button.pressed.connect(edit_to_label.bind(false))
#	edit_button.pressed.connect(label_to_edit)
#
#func save():
#	if active_scene:
#		if !edit.visible:
#			label_to_edit()
#
#		var todos := []
#		for i in todo_container.get_children():
#			todos.append(i.name)
#		var data := {
#			"text" : edit.text,
#			"todos" : todos,
#			"color" : $VSP/Text/PC.get_theme_stylebox("panel").bg_color.to_html()
#		}
#		print(data)
#		var file = FileAccess.open(active_path, FileAccess.WRITE)
#		file.store_string(JSON.stringify(data, "\t"))
#		file.close()
#
#func open(scene: Node):
#	if !scene:
#		return
#	print(scene.get_parent().get_children())
#
#	var path := scene_file_to_note_file(scene.scene_file_path)
#	if FileAccess.file_exists(path):
#		save()
#		active_path = path
#		if !edit.visible:
#			label_to_edit()
#
#		var data = JSON.new()
#		var file = FileAccess.open(path, FileAccess.READ)
#		var error = data.parse(file.get_as_text())
#		file.close()
#
#		edit.text = data.data.get("text", "")
#		$VSP/Text/PC.get_theme_stylebox("panel").bg_color = Color(data.data.get("color", "#000000"))
#
#		for i in data.data.get("todos", []):
#			check_out_todo(i)
#	else:
#		to_empty_note()
#
#	active_scene = scene
#
#func create():
#	if !active_scene:
#		return
#	var path = scene_file_to_note_file(active_scene.scene_file_path)
#	var file = FileAccess.open(path, FileAccess.WRITE)
#	file.store_string("{\n}")
#	file.close()
#
#	save_button.hide()
#	reject_button.hide()
#	edit_button.show()
#	create_button.hide()
#
#func edit_to_label(is_saving: bool):
#	save_button.hide()
#	reject_button.hide()
#	edit_button.show()
#	create_button.hide()
#
#	if is_saving:
#		label.text = edit.text
#	else:
#		label.text = old_text
#
#	edit.hide()
#	label.show()
#
#func label_to_edit():
#	save_button.show()
#	reject_button.show()
#	edit_button.hide()
#	create_button.hide()
#
#	label.hide()
#	edit.show()
#
#	edit.text = label.text
#	old_text = label.text
#
#func to_empty_note():
#	save_button.hide()
#	reject_button.hide()
#	edit_button.hide()
#	create_button.show()
#
#	active_path = ""
#
## utilities
#
#func check_out_todo(todo_name: String):
#	var temp = NotezAutoload.check_out_todo(todo_name, self)
#	if temp is int:
#		printerr(temp, " failed to load todo")
#		return
#	checked_out_todos[todo_name] = temp
#	todo_container.add_child(temp)
#
#func scene_file_to_note_file(path: String) -> String:
#	path = path.trim_prefix("res://")
#	path = path.trim_suffix(".tscn")
#	path = path.replace("/", "-")
#	path = "res://.Notez/" + path + ".json"
#
#	return path
