extends SceneTree
# Run with the matching Godot export template after importing assets.
func _initialize():
	var pack=PCKPacker.new()
	if pack.pck_start("res://build/CharmCityBeatdown.pck")!=OK:
		quit(1)
		return
	for path in ["res://project.godot","res://startup.tscn","res://main.tscn","res://default_bus_layout.tres","res://.godot/global_script_class_cache.cfg"]:
		if pack.add_file(path,path)!=OK:
			quit(1)
			return
	for folder in ["res://scripts","res://data","res://assets","res://audio","res://.godot/imported"]:
		if not add_folder(pack,folder):
			quit(1)
			return
	var result=pack.flush()
	print("Windows resource pack: ",error_string(result))
	quit(0 if result==OK else 1)

func add_folder(pack:PCKPacker,path:String)->bool:
	var dir=DirAccess.open(path)
	if not dir: return false
	for file in dir.get_files():
		var item=path.path_join(file)
		if pack.add_file(item,item)!=OK: return false
	for folder in dir.get_directories():
		if not add_folder(pack,path.path_join(folder)): return false
	return true
