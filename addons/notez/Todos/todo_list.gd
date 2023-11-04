@tool
extends PanelContainer

@onready var todo_container : VBoxContainer = $Todos

func _ready():
	await get_tree().process_frame
	for i in NotezAutoload.todos:
		var temp = NotezAutoload.check_out_todo(i, todo_container)
		if temp is int:
			printerr(temp, " todo list loaded wrong todo!")
		else:
			todo_container.checked_out_todos[i] = temp
			todo_container.todo_container.add_child(temp)
	
	NotezAutoload.new_todo.connect(todo_container.check_out_new_todo)
