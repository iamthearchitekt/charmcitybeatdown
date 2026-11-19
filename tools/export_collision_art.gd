extends SceneTree
## Bake from the final rendered textures, including scale, pixel grid and floor alignment.
const Art=preload("res://scripts/fighter_sprites.gd")
func _initialize(): call_deferred("run")
func run():
	var art=Art.new()
	var folder=ProjectSettings.globalize_path("res://../work/collision-art")
	DirAccess.make_dir_recursive_absolute(folder)
	var metadata={}
	for kind in art.sheets.size():
		var poses={}
		for frame in 18: save_pose(poses,"base:"+str(frame),art.sprite_frame(kind,frame),kind,folder,art)
		for frame in 4: save_pose(poses,"throw:"+str(frame),art.throw_frame(kind,frame),kind,folder,art)
		for frame in 6: save_pose(poses,"grapple:"+str(frame),art.grapple_art.sprite(kind,frame,art),kind,folder,art)
		for frame in art.movement_art.entries[str(kind)].regions.size():
			save_pose(poses,"movement:"+str(frame),art.movement_art.sprite(kind,frame,art),kind,folder,art)
		for key in art.style_art.keys_for(kind):
			save_pose(poses,"style:"+key,art.style_art.sprite(key),kind,folder,art)
		if art.signature_art.entries.has(str(kind)):
			# Populate signature cache with the same factory and normalization as the renderer.
			for move in art.move_tables.fighters[kind].moves.values():
				if not move.has("animation"): continue
				for frame in range(int(move.startup+move.active+move.recovery)):
					var f={"kind":kind,"frame":frame}
					var index=art.signature_art.animation_frame(f,move)
					if index>=0: save_pose(poses,"signature:"+str(index),art.signature_art.sprite(f,move,art),kind,folder,art)
		metadata[str(kind)]=poses
	var file=FileAccess.open(folder.path_join("metadata.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata))
	print("COLLISION ART EXPORTED: ",metadata.size()," fighters")
	quit()
func save_pose(poses:Dictionary,key:String,sprite:Dictionary,kind:int,folder:String,art):
	if poses.has(key): return
	art.cache_ground_contacts(sprite)
	var name=str(kind)+"-"+key.replace(":","-")+".png"
	sprite.texture.get_image().save_png(folder.path_join(name))
	poses[key]={"file":name,"size":[sprite.size.x,sprite.size.y],"anchor":sprite.anchor,"ground_gap":sprite.ground_gap}
