@tool

extends EditorContextMenuPlugin

var _randomizer_svg = preload("res://addons/create_actor/CreateRandomizer.svg")

func select_type(args : Array[String]):
	var randomizer = AudioStreamRandomizer.new()
	for stream in get_streams(args):
		randomizer.add_stream(-1, stream, 1.0)
	
	var root = args[0].get_base_dir()
	var resource_path = root + "/" + "randomizer.tres"
	
	if FileAccess.file_exists(resource_path):
		EditorInterface.get_editor_toaster().push_toast("Cannot create randomizer: File already exists.", EditorToaster.SEVERITY_WARNING)
		return
		
	ResourceSaver.save(randomizer, resource_path)

func get_streams(paths: Array[String]) -> Array[AudioStream]:
	var streams : Array[AudioStream]
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
			
		var result = ResourceLoader.load(path)
		if result is AudioStream:
			streams.append(result)
	return streams
	
func has_any_streams(paths: PackedStringArray) -> bool:
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
			
		var result = ResourceLoader.load(path)
		if result is AudioStream:
			return true
	return false
		
func _popup_menu(paths: PackedStringArray) -> void:
	if paths.size() > 0 and has_any_streams(paths):
		add_context_menu_item(&"Create AudioStreamRandomizer...", select_type, _randomizer_svg)
