extends RefCounted
## Geographic city silhouette with schematic harbor/roads, rastered once on load.
const ORIGIN=Vector2(552,130)
const SIZE=Vector2(176,210)
var data:Dictionary
var texture:Texture2D

func _init():
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/baltimore-select-map.json"))
	var image=Image.create(88,105,false,Image.FORMAT_RGBA8)
	var land=polygon(data.boundary)
	var water=polygon(data.harbor)
	for y in image.get_height():
		for x in image.get_width():
			var point=Vector2(x+.5,y+.5)*2
			if not Geometry2D.is_point_in_polygon(point,land): continue
			var is_water=Geometry2D.is_point_in_polygon(point,water)
			var color=Color("1c5090") if is_water else Color("bc914b")
			if (x+y)%3==0: color=color.lightened(.10)
			if x%3==0 or y%3==0: color=color.darkened(.25)
			image.set_pixel(x,y,color)
	texture=ImageTexture.create_from_image(image)

func point(coordinate:Array)->Vector2:
	var b=data.bounds
	return Vector2((float(coordinate[0])-b[0])/(b[2]-b[0])*SIZE.x,(b[3]-float(coordinate[1]))/(b[3]-b[1])*SIZE.y).snapped(Vector2(2,2))

func polygon(coordinates:Array)->PackedVector2Array:
	var shape=PackedVector2Array()
	for p in coordinates: shape.append(point(p))
	return shape

func draw(canvas):
	canvas.draw_texture_rect(texture,Rect2(ORIGIN,SIZE),false)
	var edge=polygon(data.boundary)
	for i in edge.size(): canvas.draw_line(ORIGIN+edge[i],ORIGIN+edge[(i+1)%edge.size()],Color("e0b568"),1)
	for road in data.roads:
		var points=polygon(road)
		for i in range(1,points.size()): canvas.draw_line(ORIGIN+points[i-1],ORIGIN+points[i],Color("705837"),1)
	canvas.arcade_text("BALTIMORE CITY",562,123,17,Color("ffe596"))
	canvas.arcade_text("N",735,146,12,Color("9eb9ed"))
	canvas.draw_line(Vector2(740,154),Vector2(740,174),Color("9eb9ed"),2)
	canvas.draw_line(Vector2(740,154),Vector2(736,160),Color("9eb9ed"),2)
	for marker in data.markers:
		var at=ORIGIN+point(marker.at)
		var label=Vector2(marker.label[0],marker.label[1])
		var left=label.x<640
		var elbow=Vector2(536 if left else 746,label.y-5)
		var end=Vector2(label.x+135 if left else label.x-8,label.y-5)
		canvas.draw_line(at,elbow,Color("879ac0"),1)
		canvas.draw_line(elbow,end,Color("879ac0"),1)
		canvas.draw_rect(Rect2(at-Vector2(3,3),Vector2(6,6)),Color("050a20"))
		canvas.draw_rect(Rect2(at-Vector2(2,2),Vector2(4,4)),Color("fff0a8"))
		canvas.arcade_text(marker.name,label.x,label.y,13,Color("ebd2a0"))
