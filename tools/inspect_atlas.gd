extends SceneTree
func _initialize():
	for name in ["breakwater","redline"]:
		var img=Image.load_from_file("res://assets/"+name+"-atlas.png")
		print(name," ",img.get_size()," format=",img.get_format()," alpha=",img.detect_alpha())
		var w=img.get_width()
		var h=img.get_height()
		var visited=PackedByteArray()
		visited.resize(w*h)
		var components=[]
		for y in h:
			for x in w:
				var start=y*w+x
				if visited[start] or img.get_pixel(x,y).a<0.2: continue
				var stack=PackedInt32Array([start])
				visited[start]=1
				var count=0
				var lo=Vector2i(x,y)
				var hi=lo
				while stack.size()>0:
					var point=stack[-1]
					stack.resize(stack.size()-1)
					var px=point%w
					var py=point/w
					count+=1
					lo.x=mini(lo.x,px);lo.y=mini(lo.y,py)
					hi.x=maxi(hi.x,px);hi.y=maxi(hi.y,py)
					for n in [point-1,point+1,point-w,point+w]:
						if n<0 or n>=w*h or visited[n]: continue
						var nx=n%w
						var ny=n/w
						if abs(nx-px)+abs(ny-py)>1: continue
						visited[n]=1
						if img.get_pixel(nx,ny).a>=0.2: stack.append(n)
				if count>1000: components.append({"x":lo.x,"y":lo.y,"w":hi.x-lo.x+1,"h":hi.y-lo.y+1,"area":count})
		print(JSON.stringify(components))
	quit()
