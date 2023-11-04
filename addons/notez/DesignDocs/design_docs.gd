@tool
extends PanelContainer

class_name NotezDesignDoc

const DEFAULT_DOC := {
	"name" : "!NAME NOT PROVIDED!",
	"color" : "#000000",
	"tags" : [],
	"text" : "",
	"todos" : [],
	"gotos" : [],
}
const TABLE = preload("res://addons/notez/DesignDocs/table.tscn")
const TAG_MANAGER = preload("res://addons/notez/tag_manager.tscn")

enum SortMode {NAME, TAG, COLOR, NONE}

var goto := preload("res://addons/notez/DesignDocs/goto.tscn")
var last_goto_used

var interface : EditorInterface

var sort_mode : SortMode = SortMode.NAME
var old_text : String
var file_path : String
var curr_tree_item : TreeItem
var main_tree_item : TreeItem

var tags : PackedStringArray
var checked_out_todos : Dictionary # "name" : todo(Node)

@onready var tree : Tree = $VS/VB/Tree
@onready var doc_color_panel : PanelContainer = $VS/Main/SC/VB/Title

@onready var edit_button : Button = $VS/Main/SC/VB/TextControls/Edit
@onready var save_button : Button = $VS/Main/SC/VB/TextControls/Save
@onready var reject_button : Button = $VS/Main/SC/VB/TextControls/Reject

@onready var edit : TextEdit = $VS/Main/SC/VB/Text/TextEdit
@onready var label : RichTextLabel = $VS/Main/SC/VB/Text/RichTextLabel

@onready var todo_container : VBoxContainer = $VS/Main/SC/VB/Todos
@onready var table_container : Control = $VS/Main/SC/VB/Text/RichTextLabel/Tables
@onready var goto_container : Control = $VS/Main/SC/VB/Text/RichTextLabel/Gotos

func _ready():
	
	NotezAutoload.save.connect(save)
	
	edit.lines_edited_from.connect(func(from_line: int, to_line: int):
		if from_line+1 == to_line:
			var regex = RegEx.create_from_string("\\s+[+->~]")
			var res = regex.search(edit.get_line(from_line))
			if res:
				edit.set_line(to_line, res.strings[0] + edit.get_line(to_line))
				await get_tree().process_frame
				edit.set_caret_column(edit.get_line(to_line).length())
		)
	
	# setup tree
	make_tree()
	curr_tree_item = main_tree_item

	tree.button_clicked.connect(func(item: TreeItem, col: int, id: int, _mbi: int):
		var path : String = item.get_text(0)
		while item.get_parent():
			item = item.get_parent()
			path = item.get_text(0) + "/" + path
		path = "res://.Notez/docs" + path
		if path == "res://.Notez/docs/main.json":
			return
		DirAccess.remove_absolute(path)

		open("res://.Notez/docs/main.json")
		curr_tree_item = main_tree_item
		make_tree()
		)
	
	# doc controls
	var color_picker : ColorPickerButton = $VS/Main/SC/VB/TextControls/DocColor
	var picker := color_picker.get_picker()
	picker.can_add_swatches = false
	for i in NotezAutoload.COLORS:
		picker.add_preset(Color(i))
	
	color_picker.color_changed.connect(set_doc_color)
	edit_button.pressed.connect(label_to_edit)
	save_button.pressed.connect(edit_to_label.bind(true))
	reject_button.pressed.connect(edit_to_label.bind(false))
	
	# file controls
	var create_file_dialog : FileDialog = $VS/VB/HB/Add/CreateDoc
	$VS/VB/HB/Add.pressed.connect(create_file_dialog.show)
	create_file_dialog.file_selected.connect(create)
	var delete_doc_dialog : ConfirmationDialog = $VS/VB/HB/Delete/DeleteDoc
	$VS/VB/HB/Tags.pressed.connect(func():
		var temp = TAG_MANAGER.instantiate()
		add_child(temp)
		temp.setup(NotezAutoload.docs_tags, tags)
		temp.new_tags.connect(func(new_tags):
			tags = new_tags
			temp.queue_free()
			)
		)
	$VS/VB/HB/Delete.pressed.connect(delete_doc_dialog.show)
	delete_doc_dialog.confirmed.connect(func():
		var path : String = curr_tree_item.get_text(0)
		while curr_tree_item.get_parent():
			curr_tree_item = curr_tree_item.get_parent()
			path = curr_tree_item.get_text(0) + "/" + path
		path = "res://.Notez/docs" + path
		if path == "res://.Notez/docs/main.json":
			return
		DirAccess.remove_absolute(path)
		
		open("res://.Notez/docs/main.json")
		curr_tree_item = main_tree_item
		make_tree()
		)
	
	var text_input : LineEdit = $VS/VB/HB/SortInput
	var color_input : Button = $VS/VB/HB/SortColor
	$VS/VB/HB/MenuButton.get_popup().id_pressed.connect(func(id: int):
		var menu = $VS/VB/HB/MenuButton
		match id:
			0:
				menu.text = "Sort: Name"
				sort_mode = SortMode.NAME
				text_input.show()
				color_input.hide()
			1:
				menu.text = "Sort: Tag"
				sort_mode = SortMode.TAG
				text_input.show()
				color_input.hide()
			2:
				menu.text = "Sort: Color"
				sort_mode = SortMode.COLOR
				text_input.hide()
				color_input.show()
			3:
				menu.text = "Sort: None"
				sort_mode = SortMode.NONE
				text_input.show()
				color_input.hide()
				call_tree_recursive(sort_none, 0, tree.get_root())
		)
	text_input.text_changed.connect(func(text: String):
		match sort_mode:
			SortMode.NAME:
				call_tree_recursive(sort_by_name, text, tree.get_root())
			SortMode.TAG:
				call_tree_recursive(sort_by_tag, text, tree.get_root())
		)
	
	color_input.pressed.connect(func():
		var used_colors : Array[Color]
		var get_colors : Callable = func(item: TreeItem, fn: Callable):
			if !used_colors.has(item.get_custom_bg_color(0)):
				used_colors.append(item.get_custom_bg_color(0))
			for i in item.get_children():
				fn.call(i, fn)
		get_colors.call(tree.get_root(), get_colors)
		$"../"
		var gc : GridContainer = color_input.get_node("P/PC/GC")
		for i in gc.get_children():
			i.queue_free()
		var sort_color : Callable = func(color: Color):
			call_tree_recursive(sort_by_color, color, tree.get_root())
		for i in used_colors:
			var temp = Button.new()
			temp.custom_minimum_size = Vector2.ONE * 30
			var stylebox = StyleBoxFlat.new()
			stylebox.bg_color = i
			temp.add_theme_stylebox_override("normal", stylebox)
			temp.add_theme_stylebox_override("hover", stylebox)
			temp.add_theme_stylebox_override("pressed", stylebox)
			temp.add_theme_stylebox_override("disabled", stylebox)
			temp.add_theme_stylebox_override("focus", stylebox)
			
			temp.pressed.connect(sort_color.bind(i))
			gc.add_child(temp)
		color_input.get_node("P").show()
		color_input.get_node("P").size = gc.size
	)
	
#	color_input.get_picker().color_changed.connect(func(color: Color):
#		call_tree_recursive(sort_by_color, color, tree.get_root())
#		)
#	for i in NotezAutoload.COLORS:
#		color_input.get_picker().add_preset(Color(i))
	
	# goto controls
	
	var jumps : MenuButton = $VS/Main/SC/VB/TextControls/GotoJumps
	jumps.pressed.connect(func():
		jumps.get_popup().clear()
		for i in goto_container.get_children():
			jumps.get_popup().add_item(i.name)
		)
	jumps.get_popup().index_pressed.connect(func(index: int):
		$VS/Main/SC.get_v_scroll_bar().value = \
			goto_container.get_node(jumps.get_popup().get_item_text(index)).position.y
		)
	
	$VS/Main/GotoControls/Add.pressed.connect(func():
		var temp = goto.instantiate()
		goto_container.add_child(temp)
		temp.position = Vector2(10, 0)
		temp.get_node("L").text_changed.connect(func(new_text: String):
			temp.name = new_text)
		temp.get_node("T").focus_entered.connect(func():
			last_goto_used = temp)
		temp.get_node("T").focus_exited.connect(func():
			last_goto_used = null)
		)
	$VS/Main/GotoControls/Delete.pressed.connect(func():
		print(last_goto_used)
		if last_goto_used:
			last_goto_used.queue_free())
	$VS/Main/GotoControls/Hide.toggled.connect(func(button_pressed: bool):
		goto_container.visible = button_pressed
		)
	
	label.meta_clicked.connect(parse_meta)

func set_doc_color(color: Color):
	doc_color_panel.get_theme_stylebox("panel").bg_color = color
	if curr_tree_item:
		curr_tree_item.set_custom_bg_color(0, color)

func edit_to_label(save: bool):
	if save:
		label.text = edit.text
	else:
		label.text = old_text
	
	if label.text.length() > 0 && label.text[-1] != "\n":
		label.text += "\n"
	
	edit.hide()
	label.show()
	
	save_button.hide()
	reject_button.hide()
	edit_button.show()
	
	# tables!
	
	var rolling_string_index_adjust : int = 0
	var table_regex : RegEx = RegEx.create_from_string("\\[table.*\\[/table\\]")
	var table_texts := table_regex.search_all(label.text)
	for i in table_texts:
		var datas = RegEx.create_from_string("((?<attribute>\\S+?)=\"(?<value>[^\"]+)*\")")
		var result := {
			"rows" : 2,
			"columns" : 2,
			"width" : 100,
	 		"height" : 50,
			"offset" : 10,
		}
		var cell_data : Dictionary
		for j in datas.search_all(i.strings[0]):
			if result.has(j.get_string("attribute")):
				var value = j.get_string("value")
				if value.is_valid_int():
					value = value.to_int()
				result[j.get_string("attribute")] = value
			else:
				cell_data[j.get_string("attribute")] = j.get_string("value")
		result["cell_data"] = cell_data
		
		var title = i.strings[0].trim_suffix("[/table]")
		result["title"] = title.substr(title.rfind("]")+1)
		
		var table = TABLE.instantiate()
		table.from_dict(result)
		table_container.add_child(table)
		
		var line_height = theme.get_font("normal_font", "RichTextLabel").get_height()
		table.char_pos = i.get_start()
		
		var height_adjust = label.get_character_line(table.char_pos)
		if height_adjust == -1:
			height_adjust = label.get_character_line(table.char_pos-1)
		table.position.y = line_height * height_adjust
		
		label.text = label.text.erase(i.get_start(), i.strings[0].length())
		var new_lines := PackedByteArray()
		table.new_line_count = clamp(roundi(table.size.y / line_height), 0, 10000)
		new_lines.resize(table.new_line_count)
		new_lines.fill(10)
		label.text = label.text.insert(i.get_start(), new_lines.get_string_from_ascii())
		
		print(table.position.x)

func label_to_edit():
	edit.text = label.text
	old_text = label.text
	
	edit.show()
	label.hide()
	
	save_button.show()
	reject_button.show()
	edit_button.hide()
	
	edit.begin_complex_operation()
	for i in table_container.get_children():
		i.queue_free()
		edit.text = edit.text.erase(i.char_pos, i.new_line_count)
		edit.text = edit.text.insert(i.char_pos, i.to_text())
	edit.end_complex_operation()

func save() -> void:
	if !FileAccess.file_exists(file_path) || file_path == "":
		return
	var todos : Array[String]
	var gotos : Array[Dictionary]
	
	if label.visible:
		label_to_edit()
	
	for i in todo_container.todo_container.get_children():
		todos.append(i.name)
	
	for i in goto_container.get_children():
			gotos.append({
				"name" : i.name,
				"position" : i.position.y
			})
	
	var result : Dictionary = {
		"color" : doc_color_panel.get_theme_stylebox("panel").bg_color.to_html(),
		"tags" : tags,
		"text" : edit.text,
		"todos" : todos,
		"gotos" : gotos,
	}
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	
	edit_to_label(true)

func open(new_file_path: String) -> void:
	if label.visible:
		label_to_edit()
	
	file_path = new_file_path
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	var data := JSON.parse_string(file.get_as_text())
	file.close()
	
	$VS/Main/SC/VB/Title/Title.text = file_path.get_file()
	var temp = StyleBoxFlat.new()
	temp.bg_color = Color(data.get("color", "#000000"))
	doc_color_panel.add_theme_stylebox_override("panel", temp)
	tags = data.get("tags", [])
	edit.text = data.get("text", "")
	
	todo_container.clear_todos()
	for i in data.get("todos", []):
		todo_container.check_out_todo(i)
	
	for i in goto_container.get_children():
		i.queue_free()
	for i in data.get("gotos", []):
		var temp_goto = goto.instantiate()
		goto_container.add_child(temp_goto)
		temp_goto.position = Vector2(10, i["position"])
		temp_goto.name = i["name"]
		temp_goto.get_node("L").text = i["name"]
		temp_goto.get_node("L").text_changed.connect(func(new_text: String):
			temp_goto.name = new_text)
		temp_goto.get_node("T").focus_entered.connect(func():
			last_goto_used = temp_goto)
		temp_goto.get_node("T").focus_exited.connect(func():
			last_goto_used = null)
	
	edit_to_label(true)

func create(path: String) -> void:
	var doc = DEFAULT_DOC.duplicate()
	doc["name"] = path.get_file()
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(doc, "\t"))
	file.close()
	
	make_tree()

func parse_meta(text: String):
	if FileAccess.file_exists(text):
		print("testing")
		var res = ResourceLoader.load(text)
		if res is Resource:
			interface.edit_resource(res)
	elif NotezAutoload.docs.has(text.get_slice(":", 0)):
		save()
		open(NotezAutoload.docs[text.get_slice(":", 0)])
		tree.deselect_all()
		print(text.get_slice_count(":"))
		if text.get_slice_count(":") == 2:
			print(goto_container.get_child(0).name)
			if goto_container.get_node_or_null(text.get_slice(":", 1)):
				
				await get_tree().process_frame
				$VS/Main/SC.get_v_scroll_bar().value = \
					goto_container.get_node(text.get_slice(":", 1)).position.y
				print("here")

func make_tree():
	tree.clear()
	tree.hide_root = true
	var root = tree.create_item()
	root.set_metadata(0, "folder")
	make_tree_layer("res://.Notez/docs", root)
	tree.item_selected.connect(func():
		var item = tree.get_selected()
		var path := item.get_text(0)
		var item_scan = item
		while item_scan.get_parent():
			item_scan = item_scan.get_parent()
			path = item_scan.get_text(0) + "/" + path
		path = "res://.Notez/docs" + path
		if !FileAccess.file_exists(path):
			return
		
		curr_tree_item = item
		save()
		open(path)
		)
	for i in root.get_children():
		print(i.get_text(0), " !")
		if i.get_text(0) == "main.json":
			print("found it!")
			main_tree_item = i
			return

# utilities

func make_tree_layer(dir: String, tree_item: TreeItem):
	var file_icon = preload("res://addons/notez/Sprites/folder.svg")
	var doc_icon = preload("res://addons/notez/Sprites/edit.svg")
	
	for i in DirAccess.get_directories_at(dir):
		var item := tree_item.create_child()
		item.set_icon(0, file_icon)
		item.set_text(0, i)
		make_tree_layer(dir + "/" + i, item)
		item.set_metadata(0, "folder")
		item.add_button(0, preload("res://addons/notez/Sprites/delete.svg"))
	for i in DirAccess.get_files_at(dir):
		var item := tree_item.create_child()
		var file = FileAccess.open(dir + "/" + i, FileAccess.READ)
		item.set_custom_bg_color(0, Color(JSON.parse_string(
				file.get_as_text()).get("color", Color.BLACK)))
		file.close()
		item.set_icon(0, doc_icon)
		item.set_text(0, i)
		item.set_metadata(0, "file")
		item.add_button(0, preload("res://addons/notez/Sprites/delete.svg"))

func add_tree_item(dir: String, curr_item: TreeItem) -> TreeItem:
	var target := dir.get_slice("/", 0)
	var is_last : bool = target == dir
	for i in curr_item.get_children():
		if i.get_text(0) == target:
			if is_last:
				return i
			else:
				return add_tree_item(dir.trim_prefix(target + "/"), i)
	
	var item := curr_item.create_child()
	item.set_text(0, target)
	if is_last:
		item.set_icon(0, preload("res://addons/notez/Sprites/edit.svg"))
		return item
	else:
		item.set_icon(0, preload("res://addons/notez/Sprites/folder.svg"))
		return add_tree_item(dir.trim_prefix(target + "/"), item)
	
	return null

func sort_by_name(item: TreeItem, text: String):
	if item.get_metadata(0) == "folder":
		return
	if text.is_empty():
		item.visible = true
		return
	if text in item.get_text(0):
		item.visible = true
	else:
		item.visible = false

func sort_by_tag(item: TreeItem, text: String):
	if item.get_metadata(0) == "folder":
		return
	if text in item.get_text(0):
		item.visible = true
	else:
		item.visible = false

func sort_by_color(item: TreeItem, color: Color):
	if item.get_metadata(0) == "folder":
		return
	var it_c = item.get_custom_bg_color(0)
	it_c = Vector3(it_c.r, it_c.g, it_c.b)
	var in_c = Vector3(color.r, color.g, color.b)
	var color_dis = it_c.distance_to(in_c)
	print(in_c, it_c, color_dis)
	if color_dis < 0.2:
		item.visible = true
	else:
		item.visible = false

func sort_none(item: TreeItem, _ignore):
	item.visible = true

func call_tree_recursive(method: Callable, arg, item: TreeItem):
	method.call(item, arg)
	for i in item.get_children():
		call_tree_recursive(method, arg, i)
