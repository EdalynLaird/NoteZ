@tool
extends Window

signal new_tags(tags: PackedStringArray)

var unused_icon : Texture2D = preload("res://addons/notez/Sprites/no.png")
var used_icon : Texture2D = preload("res://addons/notez/Sprites/yes.png")

var all_tags_list : PackedStringArray

@onready var all_tags : ItemList = $PC/HB/AllTags/TagsAll
@onready var tags_popup : PopupMenu = $TagsPopup

func _ready():
	close_requested.connect(close)
	$PC/HB/Controls/Save.pressed.connect(close)
	$PC/HB/Controls/Reject.pressed.connect(close.bind(false))
	$PC/HB/AllTags/AddTags/Add.pressed.connect(add_tag)
	all_tags.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				tags_popup.position = all_tags.get_global_mouse_position() + Vector2(position)
				tags_popup.show()
		)
	tags_popup.id_pressed.connect(func(id: int):
		if id == 0:
			var i := 0
			while i < all_tags.item_count:
				if all_tags.is_selected(i):
					all_tags_list.remove_at(all_tags_list.find(all_tags.get_item_text(i)))
					all_tags.remove_item(i)
					i -= 1
				i += 1
		elif id == 1:
			for i in all_tags.get_selected_items():
				all_tags.set_item_icon(i, used_icon)
		elif id == 2:
			for i in all_tags.get_selected_items():
				all_tags.set_item_icon(i, unused_icon)
		)

func setup(tag_list: PackedStringArray, used_tags: PackedStringArray):
	all_tags_list = tag_list
	for i in tag_list:
		if used_tags.has(i):
			all_tags.add_item(i, used_icon)
		else:
			all_tags.add_item(i, unused_icon)

func close(save: bool = true):
	if save:
		var tags : Array[String] = []
		for i in all_tags.item_count:
			if all_tags.get_item_icon(i) == used_icon:
				tags.append(all_tags.get_item_text(i))
		
		new_tags.emit(PackedStringArray(tags))
	
	hide()

func add_tag():
	var new_tag : String = $PC/HB/AllTags/AddTags/LineEdit.text
	if !all_tags_list.has(new_tag) && new_tag != "":
		all_tags_list.append(new_tag)
		all_tags.add_item(new_tag, unused_icon)
#
#func lose_tag(index: int):
#	tags_used_list.remove_at(tags_used_list.find(tags_used.get_item_text(index)))
#	tags_used.remove_item(index)
