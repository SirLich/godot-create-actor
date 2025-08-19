@tool

extends Control

@export var start : Button
@export var clear : Button
@export var apply : Button
@export var label : Label

## Maps between node_path (e.g., Parent/child), and tracked value
var position_map = {}

## Maps between node_path and AnimationPlayer, in order to revert (undo/redo)
var player_map = {}

var editor_scene_root : Node
var cached_root : Node

var editor_plugin : EditorPlugin

func configure(plugin : EditorPlugin):
	editor_plugin = plugin

func _ready() -> void:
	start.pressed.connect(on_start)
	clear.pressed.connect(on_clear)
	apply.pressed.connect(on_apply)
	
	editor_scene_root = EditorInterface.get_edited_scene_root()
	editor_plugin.scene_changed.connect(scene_changed)

func scene_changed(root : Node):
	editor_scene_root = root

func clear_data():
	label.visible = false
	start.visible = true
	clear.visible = false
	apply.visible = false
	
	if cached_root:
		cached_root.free()
	cached_root = null
	
func on_start():
	if not editor_scene_root:
		EditorInterface.get_editor_toaster().push_toast("Cannot track: No open scene.", EditorToaster.SEVERITY_WARNING)
		return
	
	clear_data()

	label.text = "Rebasing: " + editor_scene_root.name
	label.visible = true
	start.visible = false
	clear.visible = true
	apply.visible = true
	
	cached_root = editor_scene_root.duplicate()
	

#func gather_positions(node : Node):
	#if "position" in node:
		#node.get_path()
		#position_map[editor_scene_root.get_path_to(node)] = node.position
	#
	#for child in node.get_children():
		#gather_positions(child)
		
func on_clear():
	clear_data()

func justify_nodepath(player: AnimationPlayer, abs_nodepath: NodePath, property_name : String) -> NodePath:
	# Node referenced in scene
	var node := editor_scene_root.get_node(abs_nodepath)
	if node == null:
		push_error("Node not found: %s" % abs_nodepath)
		return abs_nodepath

	# The root node that animations resolve against
	var anim_root: Node = player.get_node(player.root_node)
	
	# Compute relative path from anim_root to node
	var relative_path := anim_root.get_path_to(node)

	# Append the property that we know we’re animating
	return NodePath(str(relative_path) + ":" + property_name)
	
func get_animations_players(node : Node) -> Array[AnimationPlayer]:
	var results : Array[AnimationPlayer]
	if node is AnimationPlayer:
		results.append(node)
		
	for child in node.get_children():
		results.append_array(get_animations_players(child))
		
	return results

func get_all_nodes(node : Node) -> Array[Node]:
	var results : Array[Node]
	results.append(node)
	for child in node.get_children():
		results.append_array(get_all_nodes(child))
		
	return results
	
func on_apply():
	var undo_redo = editor_plugin.get_undo_redo()
	undo_redo.create_action("retarget_animations")
	undo_redo.add_do_method(self, "apply_animation_retargeting")
	undo_redo.add_undo_method(self, "revert_animation_retargeting")
	undo_redo.commit_action()

func revert_animation_retargeting():
	for player in get_animations_players(editor_scene_root):
		player.replace_by(player_map[player.get_path()])
		
func apply_animation_retargeting():
	player_map = {}
	for player in get_animations_players(editor_scene_root):
		player_map[player.get_path()] = player
		process_animations(player)
	clear_data()

func process_animations(player : AnimationPlayer):
	var library = player.get_animation_library("")
	for animation_key in library.get_animation_list():
		process_animation(player, library.get_animation(animation_key))
	
func test():
	pass

func is_property_valid(prop_info : Dictionary):
	var valid_types = [
		Variant.Type.TYPE_FLOAT, 
		Variant.Type.TYPE_INT, 
		Variant.Type.TYPE_VECTOR2, 
		Variant.Type.TYPE_VECTOR2I,
		Variant.Type.TYPE_VECTOR3,
		Variant.Type.TYPE_VECTOR3I,
		Variant.Type.TYPE_VECTOR4,
		Variant.Type.TYPE_VECTOR4I
	]
	return prop_info["type"] in valid_types
	
func process_animation(player : AnimationPlayer, animation : Animation):
	for node in get_all_nodes(editor_scene_root):
		for prop_info in node.get_property_list():
			if not is_property_valid(prop_info):
				continue
			
			var property_name = prop_info["name"]
			var value = node[property_name]
			var node_path = editor_scene_root.get_path_to(node)
			var justified_nodepath = justify_nodepath(player, node_path, property_name)
			var track_index = animation.find_track(justified_nodepath, Animation.TrackType.TYPE_VALUE)
			
			if track_index >= 0:
				process_animation_track(animation, track_index, node_path, value)
				EditorInterface.get_editor_toaster().push_toast("Rebased track: " + str(justified_nodepath), EditorToaster.SEVERITY_INFO)
			else:
				pass
				#EditorInterface.get_editor_toaster().push_toast("Failed to rebase track: " + str(justified_nodepath), EditorToaster.SEVERITY_WARNING)
			
func process_animation_track(animation : Animation, track_index : int, node_path : NodePath, value):
	for key_index in animation.track_get_key_count(track_index):
		# Value = The old value (saved earlier)
		# The current value, in the key
		var current_key_value = animation.track_get_key_value(track_index, key_index)
		# The current value, of the node
		var current_node_value = editor_scene_root.get_node(node_path).position
		
		var difference = current_node_value - value
		var desired_value = current_key_value + difference
		
		animation.track_set_key_value(track_index, key_index, desired_value)
