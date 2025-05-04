@tool
extends EditorPlugin

var plugin_script = preload("res://addons/create_actor/create_actor.gd")
var plugin : EditorContextMenuPlugin

func _enter_tree() -> void:
	plugin = plugin_script.new()
	add_context_menu_plugin(EditorContextMenuPlugin.ContextMenuSlot.CONTEXT_SLOT_FILESYSTEM_CREATE, plugin)

func _exit_tree() -> void:
	remove_context_menu_plugin(plugin)
