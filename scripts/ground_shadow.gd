extends RefCounted
## A flattened, pixel-aligned shadow with a low-opacity edge.

static func draw(canvas:Node2D,center:Vector2,radius:float,depth:float,opacity:float):
	var edge_color=Color(.015,.018,.024,opacity*.35)
	var center_x=roundf(center.x)
	var center_y=roundf(center.y)
	for row in range(-ceili(depth),ceili(depth)):
		var v=(float(row)+.5)/depth
		if absf(v)>=1.0: continue
		var half_width=roundf(radius*sqrt(1.0-v*v))
		canvas.draw_rect(Rect2(center_x-half_width,center_y+row,half_width*2,1),edge_color)
		var core_width=roundf(half_width*.78)
		var core_color=Color(.015,.018,.024,opacity*.68*(1.0-v*v))
		canvas.draw_rect(Rect2(center_x-core_width,center_y+row,core_width*2,1),core_color)
