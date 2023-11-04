@tool
extends EditorPlugin

const DIRECTORY : Dictionary = {
	".Notez" : {
		"docs" : {
			"main.json" : "{}"},
		"todos.json" : "{}",
		"general.json" : "{}",
	}
}

var design_docs : NotezDesignDoc
var scene_notes : Node
var todo_list : Node

func _enter_tree():
	design_docs = preload("res://addons/notez/DesignDocs/design_docs.tscn").instantiate()
	scene_notes = preload("res://addons/notez/Scene Notes/scene_notes.tscn").instantiate()
	todo_list = preload("res://addons/notez/Todos/todo_list.tscn").instantiate()
	design_docs.visible = false
	
	_make_directories("res://", DIRECTORY)
	add_autoload_singleton("NotezAutoload", "res://addons/notez/notez_autoload.gd")
	
	get_editor_interface().get_editor_main_screen().add_child(design_docs)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, scene_notes)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, todo_list)
	
	await get_tree().create_timer(1).timeout
	scene_changed.connect(scene_notes.chenge_scene)
	design_docs.open("res://.Notez/docs/main.json")
	design_docs.interface = get_editor_interface()

func _exit_tree():
	remove_autoload_singleton("NotezAutoload")
	
	remove_control_from_docks(scene_notes)
	remove_control_from_docks(todo_list)
	scene_notes.queue_free()
	todo_list.queue_free()

	if design_docs:
		design_docs.queue_free()

func _has_main_screen():
	return true

func _get_plugin_name():
	return "NoteZ"

func _make_visible(visible):
	if design_docs:
		design_docs.visible = visible

func _get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return preload("res://addons/notez/Sprites/icon.png")

func _make_directories(current_path: String, things_to_make: Dictionary):
	for i in things_to_make:
		if !(things_to_make[i] is String):
			if !DirAccess.dir_exists_absolute(current_path + "/" + i):
				DirAccess.make_dir_recursive_absolute(current_path + "/" + i)
			if things_to_make[i] is Dictionary:
				_make_directories(current_path + "/" + i, things_to_make[i])
		else:
			if !FileAccess.file_exists(current_path + "/" + i):
				var file := FileAccess.open(current_path + "/" + i, FileAccess.WRITE)
				file.store_string(things_to_make[i])
				file.close()

#
#var tc:TabContainer = editorplugin.get_editor_interface().get_file_system_dock().get_parent() as TabContainer
#        tc.current_tab = tc.get_tab_idx_from_control(editorplugin.get_editor_interface().get_file_system_dock())

#
#static var todo_list
#
#var design_docs_tab
#var docs_button
#var scene_notes
#
#func _enter_tree():
#	scene_notes = load("res://addons/notez/Scene Notes/scene_notes.tscn").instantiate()
#	design_docs_tab = preload("res://addons/notez/Design Docs/design_docs_editor.tscn").instantiate()
#	todo_list = preload("res://addons/notez/TODO/todo_list.tscn").instantiate()
#	get_editor_interface().get_editor_main_screen().add_child(design_docs_tab)
#	add_autoload_singleton("NotezAutoload", "res://addons/notez/notez_autoload.gd")
#	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, scene_notes)
#	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, todo_list)
#
#	scene_changed.connect(scene_notes.open_scene)
#	get_editor_interface().get_file_system_dock().file_removed.connect(scene_notes.remove_scene)
#	#get_editor_interface().get_command_palette().add_command("test", "A", func(): print("test"), "A")
#
#	_make_directories("res://", DIRECTORY)
#
#
#func _exit_tree():
#	remove_autoload_singleton("NotezAutoload")
#	remove_control_from_docks(scene_notes)
#	remove_control_from_docks(todo_list)
#	scene_notes.queue_free()
#
#	if design_docs_tab:
#		design_docs_tab.queue_free()
#
#func _has_main_screen():
#	return true
#
#func _get_plugin_name():
#	return "NoteZ"
#
#func _make_visible(visible):
#	if design_docs_tab:
#		design_docs_tab.visible = visible
#
#func _get_plugin_icon():
#	# Must return some kind of Texture for the icon.
#	return preload("res://addons/notez/Sprites/icon.png")
#
#func _make_directories(current_path: String, things_to_make: Dictionary):
#	for i in things_to_make:
#		if (current_path + i).get_extension() == "":
#			if !DirAccess.dir_exists_absolute(current_path + i):
#				DirAccess.make_dir_recursive_absolute(current_path + i)
#			if things_to_make[i] is Dictionary:
#				_make_directories(current_path + i, things_to_make[i])
#		else:
#			var file := FileAccess.open(current_path + i, FileAccess.WRITE)
#			file.close()
