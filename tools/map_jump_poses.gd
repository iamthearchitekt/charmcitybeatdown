extends SceneTree
func _initialize():
	var img=Image.load_from_file("res://assets/jump-poses.png")
	var result=[]
	var cell=Vector2i(img.get_width()/4,img.get_height()/2)
	for row in 2:
		for col in 4:
			var origin=Vector2i(col*cell.x,row*cell.y)
			var lo=origin+cell
			var hi=origin
			for y in range(origin.y,origin.y+cell.y):
				for x in range(origin.x,origin.x+cell.x):
					if img.get_pixel(x,y).a<.2: continue
					lo.x=mini(lo.x,x);lo.y=mini(lo.y,y)
					hi.x=maxi(hi.x,x);hi.y=maxi(hi.y,y)
			result.append([lo.x,lo.y,hi.x-lo.x+1,hi.y-lo.y+1])
	FileAccess.open("res://data/jump-poses.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  ")+"\n")
	print("Jump atlas regions: ",result)
	quit()
