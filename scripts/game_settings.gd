extends RefCounted

const PATH="user://game-settings.cfg"
const SPEED_SETTING_VERSION=2

static func read()->ConfigFile:
	var config=ConfigFile.new()
	var error=config.load(PATH)
	if error!=OK and error!=ERR_FILE_NOT_FOUND:
		push_warning("Could not load game settings: "+error_string(error))
		config.clear()
	if int(config.get_value("gameplay","speed_setting_version",1))<SPEED_SETTING_VERSION:
		# The old Turbo pace is now Normal. Preserve that pace until Turbo is enabled again.
		config.set_value("gameplay","turbo",false)
		config.set_value("gameplay","speed_setting_version",SPEED_SETTING_VERSION)
		if error==OK: save(config)
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
