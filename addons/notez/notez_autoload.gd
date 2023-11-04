@tool
extends Node

signal save
signal new_todo(todo_name: String)

const COLORS : PackedStringArray = [
	"ffffff", "fb6b1d", "e83b3b", "831c5d",
	"c32454", "f04f78", "f68181", "fca790",
	"e3c896", "ab947a", "966c6c", "625565",
	"3e3546", "0b5e65", "0b8a8f", "1ebc73",
	"91db69", "fbff86", "fbb954", "cd683d",
	"9e4539", "7a3045", "6b3e75", "905ea9",
	"a884f3", "eaaded", "8fd3ff", "4d9be6",
	"4d65b4", "484a77", "30e1b9", "8ff8e2",
]
const DEFAULT_TODO := {
	"checked" : false,
	"name" : "",
	"tags" : [],
	"Progress Log" : "",
}

var todo_tags : PackedStringArray
var docs_tags : PackedStringArray

var notes : Dictionary # "scene path" : "note path"
var docs : Dictionary # "name" : "path"
var todos : Dictionary # "name" : todo(Dict)
var checked_out_todos : Dictionary # "name" : [objects_that_checked_it_out]

func _ready():
	save.connect(save_todos)
	
	var file = FileAccess.open("res://.Notez/todos.json", FileAccess.READ)
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	if error == OK:
		todos = json.data
	else:
		printerr("res://.Notez/todos.json load failed: ", error)
	file.close()
	
	file = FileAccess.open("res://.Notez/general.json", FileAccess.READ)
	json = JSON.new()
	error = json.parse(file.get_as_text())
	if error == OK:
		todo_tags = json.data.get("todo_tags", [])
		docs_tags = json.data.get("docs_tags", [])
	else:
		printerr("res://.Notez/general.json load failed: ", error)
	file.close()
	
	var all_docs : Array[String]
	find_all_docs("res://.Notez/docs", all_docs)
	for i in all_docs:
		docs[i.get_file()] = i

func _input(event):
	if event is InputEventKey:
		if OS.get_keycode_string(event.get_key_label_with_modifiers()) == "Ctrl+S":
			save.emit()

## returns the todo with name of todo_name, or an error if the todo doesn't exist
##
## the node checking the todo out needs to have a function:
## get_checked_out_todo(todo_name: String, delete: bool) -> NotezTodo
## and
## update_todo(todo_name: String, new_dict: Dictionary) -> void
func check_out_todo(todo_name: String, calling_from: Object):
	if !calling_from.has_method("get_checked_out_todo"):
		printerr(calling_from, " needs to have the get_checked_out_todo(todo_name: String, delete: bool) -> NotezTodo function to call this method")
		return ERR_UNAUTHORIZED
	
	if !todos.has(todo_name):
		printerr("todo with name ", todo_name, " doesn't exist")
		return ERR_DOES_NOT_EXIST
	
	if !checked_out_todos.has(todo_name):
		checked_out_todos[todo_name] = []
	if !checked_out_todos[todo_name].has(calling_from):
		checked_out_todos[todo_name].append(calling_from)
	else:
		printerr("can't check out the same todo twice from 1 source")
		return ERR_UNAUTHORIZED
	
	var temp = NotezTodo.new_from_dict(todos[todo_name])
	temp.changed.connect(update_todo.bind(todo_name))
	return temp

## makes and returns a new todo or an error if the todo already exists
##
## the node checking the todo out needs to have a function:
## get_checked_out_todo(todo_name: String, delete: bool) -> NotezTodo
## and
## update_todo(todo_name: String, new_dict: Dictionary) -> void
func make_new_todo(todo_name: String, calling_from: Object):
	if !calling_from.has_method("get_checked_out_todo"):
		printerr(calling_from, " needs to have the get_checked_out_todo(todo_name: String) -> NotezTodo function to call this method")
		return ERR_UNAUTHORIZED
	
	if todos.has(todo_name):
		printerr("all todos must have a unique name. ", todo_name, " is already used")
		return ERR_ALREADY_EXISTS
	
	var temp_data := DEFAULT_TODO.duplicate()
	temp_data["name"] = todo_name
	var temp = NotezTodo.new_from_dict(temp_data)
	temp.changed.connect(update_todo.bind(todo_name))
	todos[todo_name] = temp.to_dict()
	
	checked_out_todos[todo_name] = [calling_from]
	
	new_todo.emit(todo_name)
	
	save_todos()
	return temp

func return_todo(todo_name, calling_from) -> void:
	checked_out_todos[todo_name].erase(calling_from)

func update_todo(new_dict: Dictionary, todo_name: String) -> void:
	todos[todo_name] = new_dict
	for i in checked_out_todos[todo_name]:
		i.update_todo(todo_name, new_dict)
	
	save_todos()

func save_todos():
	var json_string = JSON.stringify(todos, "\t")
	var file = FileAccess.open("res://.Notez/todos.json", FileAccess.WRITE)
	file.store_string(json_string)
	file.close()
	
	file = FileAccess.open("res://.Notez/general.json", FileAccess.WRITE)
	json_string = JSON.stringify({
		"todo_tags": todo_tags,
		"docs_tags": docs_tags,
	}, "\t")
	file.store_string(json_string)
	file.close()

func recall_todo(todo_name: String):
	for i in checked_out_todos[todo_name]:
		i.get_checked_out_todo(todo_name, true)
	checked_out_todos[todo_name].clear()
	todos.erase(todo_name)

func find_all_docs(curr_path: String, all_docs):
	for i in DirAccess.get_directories_at(curr_path):
		find_all_docs(curr_path + "/" + i, all_docs)
	
	for i in DirAccess.get_files_at(curr_path):
		all_docs.append(curr_path + "/" + i)
