@tool

extends Popup

@export_group("Nodes")
@export var create_button : Button
@export var cancel_button : Button
@export var actor_line_edit : LineEdit
@export var create_folder : CheckBox
@export var create_script : CheckBox

var _type = ""
var _path = ""

func _ready() -> void:
	initialize_settings()
	initialize_checkbox_values()
	
	create_button.pressed.connect(create_actor)
	cancel_button.pressed.connect(cancel)
	close_requested.connect(cancel)
	create_folder.toggled.connect(create_folder_changed)
	create_script.toggled.connect(create_script_changed)
	
	grab_focus()
	actor_line_edit.grab_focus()

const FOLDER_SETTING_NAME = &"create_actor/create_folder"
const SCRIPT_SETTING_NAME = &"create_actor/create_script"

func initialize_settings():
	var settings = EditorInterface.get_editor_settings()
	if not settings.has_setting(FOLDER_SETTING_NAME):
		settings.set_setting(FOLDER_SETTING_NAME, true)
	if not settings.has_setting(SCRIPT_SETTING_NAME):
		settings.set_setting(SCRIPT_SETTING_NAME, true)

func initialize_checkbox_values():
	var settings = EditorInterface.get_editor_settings()

	create_folder.set_pressed_no_signal(settings.get_setting(FOLDER_SETTING_NAME))
	create_script.set_pressed_no_signal(settings.get_setting(SCRIPT_SETTING_NAME))

func create_folder_changed(value : bool):
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting(FOLDER_SETTING_NAME, value)

func create_script_changed(value : bool):
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting(SCRIPT_SETTING_NAME, value)
	
func configure(path : String, type : String):
	_path = path
	_type = type

func should_create_folder() -> bool:
	var settings = EditorInterface.get_editor_settings()
	return settings.get_setting(FOLDER_SETTING_NAME)
	
func should_create_script() -> bool:
	var settings = EditorInterface.get_editor_settings()
	return settings.get_setting(SCRIPT_SETTING_NAME)
	
func _input(event: InputEvent) -> void:
	if Input.is_key_pressed(KEY_ENTER): ## To avoid space causing issues
		create_actor()
	if event.is_action("ui_cancel"):
		cancel()

func get_base_actor_name():
	return actor_line_edit.text
	
func get_actor_name_camel():
	return get_base_actor_name().to_pascal_case()
	
func get_actor_name_underscore():
	return get_base_actor_name().to_snake_case()

func scan_and_wait():
	EditorInterface.get_resource_filesystem().scan()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
		
func create_actor():
	var dir_path = _path + "/"
	if should_create_folder():
		dir_path = _path + "/" + get_actor_name_underscore()
		
	var scene_path = dir_path + "/" + get_actor_name_underscore() + ".tscn"
	var script_path = dir_path + "/" + get_actor_name_underscore() + ".gd"
	
	var _err = DirAccess.make_dir_absolute(dir_path)
	
	await scan_and_wait()
	
	var new_node = ClassDB.instantiate(_type)
	new_node.name = get_actor_name_camel()
	
	if should_create_script():
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		script_file.store_string("extends " + _type)
		script_file.close()	
		new_node.set_script(load(script_path))
	
	var new_packed = PackedScene.new()
	new_packed.pack(new_node)
	ResourceSaver.save(new_packed, scene_path)

	EditorInterface.open_scene_from_path(scene_path)
	
	if should_create_script():
		EditorInterface.edit_script(load(script_path))
	
	cancel()
	
	## Hack: Try to make sure the filesystem actually works...
	await scan_and_wait()
	await get_tree().process_frame
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(0.5).timeout
	EditorInterface.get_resource_filesystem().scan()
	
func cancel():
	hide()
