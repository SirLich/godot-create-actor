@tool

extends EditorContextMenuPlugin

var popup_packed = preload("res://addons/create_actor/create_actor_popup.tscn")
var create_actor_svg = preload("res://addons/create_actor/CreateActor.svg")
var _path = ""

func select_type(args : Array):
	EditorInterface.popup_create_dialog(select_name, "Node", "Node2D", "Create Actor of Type")
	
func select_name(type : String):
	if not type:
		return
		
	var new_popup = popup_packed.instantiate()
	new_popup.configure(_path, type)
	
	EditorInterface.popup_dialog_centered(new_popup)
	
func _popup_menu(paths: PackedStringArray) -> void:
	if paths.size() == 1:
		_path = paths[0]
		add_context_menu_item(&"Actor...", select_type, create_actor_svg)
