@tool

extends Popup

@export_group("Nodes")
@export var create_button : Button
@export var cancel_button : Button

@export var path_line_edit : LineEdit
@export var actor_line_edit : LineEdit

@export var create_folder : CheckBox
@export var script_type : OptionButton

@export var select_folder_button : Button

## The type of asset to create (e.g., Node2D)
var _type = ""
## The path where the asset has been requested to be created
var _path = ""
## The file dialog popup
var _active_file_dialog : EditorFileDialog
	
func _ready() -> void:
	initialize_settings()
	initialize_checkbox_values()
	
	create_button.pressed.connect(create_actor)
	create_folder.toggled.connect(create_folder_changed)
	script_type.item_selected.connect(script_type_changed)
	select_folder_button.pressed.connect(select_folder)
	select_folder_button.icon = EditorInterface.get_editor_theme().get_icon("Folder", "EditorIcons")
	
	cancel_button.pressed.connect(cancel)
	close_requested.connect(cancel)


const FOLDER_SETTING_NAME = &"create_actor/create_folder"
const SCRIPT_TYPE_NAME = &"create_actor/create_script"

enum SCRIPT_TYPE {
	GDScript, 
	CSharp,
	None
}


func folder_selected(dir: String):
	if _active_file_dialog:
		_active_file_dialog.queue_free()
	path_line_edit.text = ProjectSettings.localize_path(dir)
	show_window()

func show_window():
	show()
	grab_focus()
	actor_line_edit.grab_focus()
	
func select_folder():
	_active_file_dialog = EditorFileDialog.new()
	_active_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_active_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_active_file_dialog.dir_selected.connect(folder_selected)
		
	var viewport = EditorInterface.get_base_control()
	viewport.add_child(_active_file_dialog)
	_active_file_dialog.set_meta("_created_by", self)
	hide()
	_active_file_dialog.popup_centered(Vector2(700, 500))

func initialize_settings():
	var settings = EditorInterface.get_editor_settings()
	if not settings.has_setting(FOLDER_SETTING_NAME):
		settings.set_setting(FOLDER_SETTING_NAME, true)
	if not settings.has_setting(SCRIPT_TYPE_NAME):
		settings.set_setting(SCRIPT_TYPE_NAME, SCRIPT_TYPE.GDScript)

func initialize_checkbox_values():
	var settings = EditorInterface.get_editor_settings()

	create_folder.set_pressed_no_signal(settings.get_setting(FOLDER_SETTING_NAME))
	script_type.select(settings.get_setting(SCRIPT_TYPE_NAME))
	path_line_edit.text = _path

func create_folder_changed(value : bool):
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting(FOLDER_SETTING_NAME, value)

func script_type_changed(value : int):
	var settings = EditorInterface.get_editor_settings()
	settings.set_setting(SCRIPT_TYPE_NAME, value)
	
func configure(path : String, type : String):
	_path = path
	_type = type

func should_create_folder() -> bool:
	var settings = EditorInterface.get_editor_settings()
	return settings.get_setting(FOLDER_SETTING_NAME)
	
func should_create_script() -> bool:
	var settings = EditorInterface.get_editor_settings()
	return settings.get_setting(SCRIPT_TYPE_NAME) != SCRIPT_TYPE.None
	
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

func get_setting(key : String):
	return EditorInterface.get_editor_settings().get_setting(key)
	
func set_setting(key : String, value):
	EditorInterface.get_editor_settings().set_setting(key, value)

func get_script_extension():
	if get_setting(SCRIPT_TYPE_NAME) == SCRIPT_TYPE.GDScript:
		return ".gd"
	else:
		return ".cs"

func get_script_contents():
	if get_setting(SCRIPT_TYPE_NAME) == SCRIPT_TYPE.GDScript:
		return "class_name %s extends %s" % [get_actor_name_camel(), _type]
	else:
		return \
"""
using Godot;
using System;

public partial class %s : %s
{
}
""" % [get_actor_name_camel(), _type]

func create_actor():
	if get_actor_name_camel().is_empty():
		EditorInterface.get_editor_toaster().push_toast("Actor name cannot be empty", EditorToaster.SEVERITY_WARNING)
		return
	
	var dir_path = path_line_edit.text + "/"
	
	if should_create_folder():
		dir_path = dir_path + "/" + get_actor_name_underscore()
		
	var scene_path = dir_path + "/" + get_actor_name_underscore() + ".tscn"
	var script_path = dir_path + "/" + get_actor_name_underscore() + get_script_extension()
	
	var _err = DirAccess.make_dir_absolute(dir_path)
	
	await scan_and_wait()
	
	var new_node = ClassDB.instantiate(_type)
	new_node.name = get_actor_name_camel()
	
	if should_create_script():
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		script_file.store_string(get_script_contents())
		script_file.close()
		new_node.set_script(load(script_path))
	
	var new_packed = PackedScene.new()
	new_packed.pack(new_node)
	ResourceSaver.save(new_packed, scene_path)

	EditorInterface.open_scene_from_path(scene_path)
	
	if should_create_script():
		EditorInterface.edit_script(load(script_path))
		
	hide()
	
	## Hack: Try to refresh a few times to ensure the new files are actually visible
	await scan_and_wait()
	await get_tree().process_frame
	EditorInterface.get_resource_filesystem().scan()
	await get_tree().create_timer(0.5).timeout
	EditorInterface.get_resource_filesystem().scan()

	cancel()
	
func cancel():
	queue_free()
