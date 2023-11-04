@tool
extends VBoxContainer

const TEXT_INPUT = preload("res://addons/notez/DesignDocs/table_text_input.tscn")
const DEFAULT_TABLE = {
	"rows" : 2,
	"columns" : 2,
	"width" : 100,
	"height" : 50,
	"offset" : 10,
}

var table_data : Dictionary
var char_pos : int
var new_line_count : int

func to_text() -> String:
	var result := "[table"
	
	print(table_data)
	for i in DEFAULT_TABLE:
		if table_data.has(i) && table_data[i] != DEFAULT_TABLE[i]:
			result += " " + i + "=\"" + str(table_data[i]) + "\" "
	
	for i in $GC.get_children():
		if !i.get_node("L").text.is_empty():
			result += " " + i.name + "=\"" + i.get_node("L").text +"\" "
	
	result += "]" + $Title.text + "[/table]"
	
	return result
#	var result := Dictionary(table_data)
#	var cell_data := {}
#	for i in $GC.get_children():
#		if i.get_node("L").text.length() > 0:
#			cell_data[i.name] = i.get_node("L").text
#	result["cell_data"] = cell_data
#
#	return result

## data should look like this:
##	{
##		"title" : String
##		"start_pos" : int
##		"rows" : int
##		"columns" : int
##		"width" : float
## 		"height" : float
##		"cell_data" : Dictionary {"x,y": String, ...}
##	}
func from_dict(data: Dictionary) -> void:
	table_data = data
	
	$Title.text = data.get("title", "title")
	$GC.columns = data.get("columns", 2)
	position.x = data.get("offset", 10)
	
	for i in data.get("rows", 2) as int:
		for j in data.get("columns", 2) as int:
			var temp := TEXT_INPUT.instantiate()
			temp.name = str(i) + "-" + str(j)
			temp.custom_minimum_size = Vector2(data.get("width", 100), data.get("height", 50))
			$GC.add_child(temp)
	custom_minimum_size = Vector2(max(data.get("columns", 2) * (data.get("width", 100) + 3), $Title.size.x), 
								data.get("rows", 2) * (data.get("height", 50) + 3))
	for i in data["cell_data"]:
		var line_edit = $GC.get_node_or_null(i)
		if line_edit:
			line_edit.get_child(0).text = data["cell_data"][i]
