extends RefCounted

const PATH="user://game-settings.cfg"

static func read()->ConfigFile:
	var config=ConfigFile.new()
	var error=config.load(PATH)
	if error!=OK and error!=ERR_FILE_NOT_FOUND:
		push_warning("Could not load game settings: "+error_string(error))
		config.clear()
	return config

static func apply_system_settings(config:ConfigFile):
	if config.has_section_key("display","fullscreen"):
		set_fullscreen(bool(config.get_value("display","fullscreen")))
	AudioServer.set_bus_mute(0,not bool(config.get_value("audio","sound",true)))

static func fullscreen()->bool:
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]

static func set_fullscreen(enabled:bool):
	if fullscreen()!=enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

static func save(config:ConfigFile)->bool:
	var error=config.save(PATH)
	if error!=OK: push_warning("Could not save game settings: "+error_string(error))
	return error==OK
