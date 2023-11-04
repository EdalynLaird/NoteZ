@tool
extends VBoxContainer

signal made_new_todo(todo_name: String)

enum TodoSortMode {TAG, NAME, COMPLETED}

var checked_out_todos : Dictionary
var todo_sort_mode : TodoSortMode = TodoSortMode.NAME

@onready var todo_container : VBoxContainer = $ScrollContainer/TodoContainer

func _ready() -> void:
	var todo_create_window : Window = $TodoControls/NewTodo
	var pop : PopupMenu = $TodoControls/NewTodo/PC/MC/VB/MB.get_popup()
	pop.index_pressed.connect(func(index: int):
		todo_create_window.get_node("PC/MC/VB/Name").text = pop.get_item_text(index)
		)
	
	$TodoControls/Add.pressed.connect(func():
		todo_create_window.show()
		$TodoControls/NewTodo/PC/MC/VB/Name.grab_focus()
		todo_create_window.get_node("PC/MC/VB/Name").text = ""
		todo_create_window.get_node("PC/MC/VB/Error").text = ""
		
		pop.clear()
		for i in NotezAutoload.todos:
			pop.add_item(i)
		)
	todo_create_window.get_node("PC/MC/VB/HB/Create").pressed.connect(func():
		if todo_create_window.get_node("PC/MC/VB/Error").text == "":
			if NotezAutoload.todos.has(todo_create_window.get_node("PC/MC/VB/Name").text):
				check_out_todo(todo_create_window.get_node("PC/MC/VB/Name").text)
			else:
				make_new_todo(todo_create_window.get_node("PC/MC/VB/Name").text)
			todo_create_window.hide())
	todo_create_window.get_node("PC/MC/VB/HB/Cancel").pressed.connect(todo_create_window.hide)
	todo_create_window.close_requested.connect(todo_create_window.hide)
	todo_create_window.get_node("PC/MC/VB/Name").text_changed.connect(func(new_text: String):
		if todo_container.get_node_or_null(new_text):
			todo_create_window.get_node("PC/MC/VB/Error").text = "Already Have That Todo!"
		else:
			todo_create_window.get_node("PC/MC/VB/Error").text = ""
		)
	
	$TodoControls/SortInput.text_changed.connect(sort_todos)
	$TodoControls/MenuButton.get_popup().id_pressed.connect(func(id: int):
		if id == 0:
			todo_sort_mode = TodoSortMode.NAME
			$TodoControls/MenuButton.text = "Sort: Name"
		elif id == 1:
			todo_sort_mode = TodoSortMode.TAG
			$TodoControls/MenuButton.text = "Sort: Tag"
		elif id == 2:
			todo_sort_mode = TodoSortMode.COMPLETED
			$TodoControls/MenuButton.text = "Sort: Completed(y/n)"
		)

func clear_todos():
	for i in todo_container.get_children():
		i.queue_free()
		NotezAutoload.return_todo(i.name, self)

func make_new_todo(todo_name: String):
	var temp = NotezAutoload.make_new_todo(todo_name, self)
	checked_out_todos[todo_name] = temp
	todo_container.add_child(temp)
	temp.delete.connect(return_todo.bind(todo_name, temp))

func check_out_todo(todo_name: String):
	var temp = NotezAutoload.check_out_todo(todo_name, self)
	if temp is int:
		printerr(temp, " failed to load todo")
		return
	checked_out_todos[todo_name] = temp
	todo_container.add_child(temp)
	temp.delete.connect(return_todo.bind(todo_name, temp))

func get_checked_out_todo(todo_name: String, delete: bool) -> NotezTodo:
	var result = checked_out_todos[todo_name]
	if delete:
		checked_out_todos[todo_name].queue_free()
		checked_out_todos[todo_name] = null
	return result

func update_todo(todo_name: String, new_dict: Dictionary) -> void:
	todo_container.get_node(todo_name).from_dict(new_dict)

func sort_todos(text: String):
	var todos = todo_container.get_children()
	todos.sort_custom(func(a, b):
		match todo_sort_mode:
			TodoSortMode.NAME:
				return a.name.similarity(text) > b.name.similarity(text)
			TodoSortMode.TAG:
				return a.tags.has(text)
			TodoSortMode.COMPLETED:
				if text[0].to_lower() == 'y':
					return a.get_node("HB/CB").button_pressed
				else:
					return !a.get_node("HB/CB").button_pressed
		)
	for i in todos.size():
		todo_container.move_child(todos[i], i)

func check_out_new_todo(todo_name: String):
	var temp = NotezAutoload.check_out_todo(todo_name, self)
	if temp is int:
		printerr(temp, " had an error while it was loading in the todo list!")
	else:
		checked_out_todos[todo_name] = temp
		todo_container.add_child(temp)
		temp.delete.connect(return_todo.bind(todo_name, temp))

func return_todo(todo_name: String, todo: NotezTodo):
	NotezAutoload.return_todo(todo_name, self)
	todo.queue_free()
