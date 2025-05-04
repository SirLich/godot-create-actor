@tool

extends Popup

@export_group("Nodes")
@export var create_button : Button
@export var cancel_button : Button
@export var actor_line_edit : LineEdit

var _type = ""
var _path = ""

func _ready() -> void:
	create_button.pressed.connect(create_actor)
	cancel_button.pressed.connect(cancel)
	close_requested.connect(cancel)
	
	grab_focus()
	actor_line_edit.grab_focus()

func configure(path : String, type : String):
	_path = path
	_type = type

func _input(event: InputEvent) -> void:
	if event.is_action("ui_accept"):
		create_actor()
	if event.is_action("ui_cancel"):
		cancel()

func get_actor_name():
	return actor_line_edit.text

func scan_and_wait():
	EditorInterface.get_resource_filesystem().scan()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
		
func create_actor():
	print("Item Created:")
	print(_type)
	print(_path)
	
	var dir_path = _path + "/" + get_actor_name()
	var scene_path = dir_path + "/" + get_actor_name() + ".tscn"
	var script_path = dir_path + "/" + get_actor_name() + ".gd"
	
	var _err = DirAccess.make_dir_absolute(dir_path)
	if _err:
		print("Could not create actor: ", _err)
		return
	
	await scan_and_wait()
	
	var new_node = ClassDB.instantiate(_type)
	new_node.name = get_actor_name()
	
	var script_file = FileAccess.open(script_path, FileAccess.WRITE)
	script_file.store_string("extends " + _type)
	script_file.close()

	await scan_and_wait()
	
	new_node.set_script(load(script_path))
	var new_packed = PackedScene.new()
	new_packed.pack(new_node)
	ResourceSaver.save(new_packed, scene_path)

	EditorInterface.open_scene_from_path(scene_path)
	EditorInterface.edit_script(load(script_path))
	
	cancel()
	
	await scan_and_wait()
	await get_tree().process_frame
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(0.5).timeout
	EditorInterface.get_resource_filesystem().scan()
	
func cancel():
	hide()
