@tool

extends EditorPlugin

var create_actor_plugin_script = preload("res://addons/create_actor/create_actor.gd")
var create_actor_plugin : EditorContextMenuPlugin

var randomizer_plugin_script = preload("res://addons/create_actor/create_randomizer.gd")
var randomizer_plugin : EditorContextMenuPlugin
var is_dragging = false

func get_base_editor() -> CodeEdit:
	return EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	
func _enter_tree() -> void:
	create_actor_plugin = create_actor_plugin_script.new()
	add_context_menu_plugin(EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM_CREATE, create_actor_plugin)
	
	randomizer_plugin = randomizer_plugin_script.new()
	add_context_menu_plugin(EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM, randomizer_plugin)
	
	EditorInterface.get_script_editor().editor_script_changed.connect(open_script_changed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		is_dragging = true
	if what == NOTIFICATION_DRAG_END:
		await get_tree().process_frame
		is_dragging = false
	
func open_script_changed(script : Script):
	if not get_base_editor().lines_edited_from.is_connected(code_changed):
		get_base_editor().lines_edited_from.connect(code_changed)

func locate_first_node_with_script_in_open_scene(node: Node, script : Script):
	## Initial case 
	if not node:
		node = EditorInterface.get_edited_scene_root()
		
	if node.get_script() == script:
		return node
		
	for child in node.get_children():
		return locate_first_node_with_script_in_open_scene(child, script)
	
func code_changed(from: int, to: int):
	if is_dragging:
		await get_tree().process_frame
		
		var if_correct_lines_edited = from - to == -1
		if if_correct_lines_edited:
			var line = get_base_editor().get_line(from)
			
			var export_info := get_export_info(line)
			if export_info.is_valid:
				get_base_editor().set_line(from, export_info.result)
				
				var current_script = EditorInterface.get_script_editor().get_current_script()
				var node = locate_first_node_with_script_in_open_scene(null, current_script)
				
				current_script.source_code = get_base_editor().text
				ResourceSaver.save(current_script)
				
				node[export_info.var_name] = export_info.exportable_path
		
		is_dragging = false

class ExportInfo:
	var is_valid : bool
	var var_name : String
	var type_hint : String
	var path : String
	var exportable_path : NodePath
	var result : String
	
## Example: actor_line_edit = NodePath("Root/MarginContainer/Container/LineEdit")
func get_export_info(line) -> ExportInfo:
	# Example transformation:
	# @onready var select_folder: Button = $Root/MarginContainer/Container/HBoxContainer2/SelectFolder
	# @export var select_folder : Button
	
	var export_info = ExportInfo.new()


	var regex = RegEx.new()
	regex.compile("@onready var (.+): (.+) = (.+)")
	var result := regex.search(line)
	if result.get_group_count() != 3:
		export_info.is_valid = false
		return export_info # Abort
	
	
	export_info.var_name = result.get_string(1)
	export_info.type_hint = result.get_string(2)
	export_info.path = result.get_string(3)
	export_info.exportable_path = NodePath(export_info.path.lstrip("$"))
	
	export_info.result = "@export var %s : %s" % [export_info.var_name, export_info.type_hint]
	export_info.is_valid = true

	return export_info
		

func _exit_tree() -> void:
	remove_context_menu_plugin(create_actor_plugin)
	remove_context_menu_plugin(randomizer_plugin)
	
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_T):
		create_actor_plugin.select_type([])
