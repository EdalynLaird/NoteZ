@tool
extends PanelContainer

const BASE_LABEL : PackedScene = preload("res://addons/notez/Scene Notes/base_notes_label.tscn")

var curr_scene : Node
var old_text : String

var checked_out_todos : Dictionary # "name" : todo(Node)

@onready var todo_container : VBoxContainer = $VSP/Todos

@onready var save_button : Button = $VSP/Text/PC/Controls/Save
@onready var clear_button : Button = $VSP/Text/PC/Controls/Clear
@onready var edit_button : Button = $VSP/Text/PC/Controls/Edit
@onready var create_button : Button = $VSP/Text/PC/Controls/Create
@onready var refresh_button : Button = $VSP/Text/PC/Controls/Refresh
@onready var delete_button : Button = $VSP/Text/PC/Controls/Delete

@onready var base_notes : VBoxContainer = $VSP/Text/SC/VB/BaseNotes
@onready var edit : TextEdit = $VSP/Text/SC/VB/Container/TextEdit
@onready var label : RichTextLabel = $VSP/Text/SC/VB/Container/RichTextLabel

func _ready():
	var color_select : ColorPickerButton = $VSP/Text/PC/Controls/BackgroundColor
	color_select.color_changed.connect(func(color: Color):
		theme.get_stylebox("panel", "PanelContainer").bg_color = color
		)
	for i in NotezAutoload.COLORS:
		color_select.get_picker().add_preset(i)
	
	create_button.pressed.connect(create)
	save_button.pressed.connect(edit_to_label.bind(true))
	clear_button.pressed.connect(edit_to_label.bind(false))
	edit_button.pressed.connect(label_to_edit)
	delete_button.pressed.connect(delete)
	
	NotezAutoload.save.connect(save.bind(true))

func change_node(selection: EditorSelection):
	var nodes: Array[Node] = selection.get_selected_nodes()
	if nodes.size() == 0: return
	if nodes.size() != 1 && nodes[0].scene_file_path != "":
		return
	change_scene(nodes[0])

func change_scene(scene: Node):
	save()
	
	for i in base_notes.get_children():
		i.queue_free()
	$VSP/Text/PC.get_theme_stylebox("panel").bg_color = Color("#363d4a")
	
	if !scene || !FileAccess.file_exists(scene.scene_file_path):
		to_invalid_scene()
		return
	curr_scene = scene
	if !FileAccess.file_exists(scene_file_to_note_file(scene.scene_file_path)):
		to_empty_note()
		return
	
	open()
	edit_to_label(true)
	print("here")

func save(is_move: bool = false):
	if label.visible:
		label_to_edit()
	
	if !(curr_scene &&\
	FileAccess.file_exists(scene_file_to_note_file(curr_scene.scene_file_path))):
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
	
	if is_move:
		edit_to_label(true)

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
	
	var pack : PackedScene = load(curr_scene.scene_file_path)
	while pack._bundled.has("base_scene"):
		pack = pack._bundled.variants[pack._bundled.base_scene]
		var temp = BASE_LABEL.instantiate()
		file = FileAccess.open(scene_file_to_note_file(pack.resource_path), FileAccess.READ)
		if !file: return
		temp.text = JSON.parse_string(file.get_as_text()).text
		file.close()
		base_notes.add_child(temp)

func refresh():
	if !curr_scene:
		return
	if FileAccess.file_exists(curr_scene.scene_file_path):
		to_empty_note()

func create():
	save_button.hide()
	clear_button.hide()
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
	clear_button.hide()
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
	clear_button.show()
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
	clear_button.hide()
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
	clear_button.hide()
	edit_button.hide()
	create_button.hide()
	refresh_button.show()
	delete_button.hide()
	
	label.show()
	edit.hide()
	
	label.text = ""
	old_text = ""
	edit.text = ""

func delete():
	if curr_scene:
		var confirmation : ConfirmationDialog = $VSP/Text/PC/Controls/Delete/CD
		confirmation.show()
		confirmation.confirmed.connect(func():
			DirAccess.remove_absolute(scene_file_to_note_file(curr_scene.scene_file_path))
			
			label.text = ""
			edit.text = ""
			old_text = ""
			
			to_empty_note()
		)

func scene_file_to_note_file(path: String) -> String:
	path = path.trim_prefix("res://")
	path = path.trim_suffix(".tscn")
	path = path.replace("/", "-")
	path = "res://.Notez/" + path + ".json"

	return path
