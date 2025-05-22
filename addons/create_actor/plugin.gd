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

func code_changed(from: int, to: int):
	if is_dragging:
		await get_tree().process_frame
		
		var result = from - to
		prints(from, to, result)
		
		if result == 1 or result == -1:
			get_base_editor().remove_line_at(to)
			
		is_dragging = false
		
func _exit_tree() -> void:
	remove_context_menu_plugin(create_actor_plugin)
	remove_context_menu_plugin(randomizer_plugin)
	
func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_T):
		create_actor_plugin.select_type([])
