extends SceneTree
func _initialize():
	var output={}
	for name in ["alex-atlas","emma-atlas","supine-ko"]:
		var img=Image.load_from_file("res://assets/"+name+".png")
		img.convert(Image.FORMAT_RGBA8)
		var pixels=img.get_data()
		var w=img.get_width();var h=img.get_height()
		var visited=PackedByteArray();visited.resize(w*h)
		var parts=[]
		for start in w*h:
			if visited[start] or pixels[start*4+3]<51: continue
			var stack=PackedInt32Array([start]);visited[start]=1
			var count=0;var lo=Vector2i(start%w,start/w);var hi=lo
			while not stack.is_empty():
				var point=stack[-1];stack.resize(stack.size()-1)
				var px=point%w;var py=point/w
				count+=1;lo.x=mini(lo.x,px);lo.y=mini(lo.y,py);hi.x=maxi(hi.x,px);hi.y=maxi(hi.y,py)
				for n in [point-1,point+1,point-w,point+w]:
					if n<0 or n>=w*h or visited[n]: continue
					if absi(n%w-px)+absi(n/w-py)>1: continue
					visited[n]=1
					if pixels[n*4+3]>=51: stack.append(n)
			if count>1000: parts.append([lo.x,lo.y,hi.x-lo.x+1,hi.y-lo.y+1])
		parts.sort_custom(func(a,b):
			var ar=int((a[1]+a[3]-1)*4/h);var br=int((b[1]+b[3]-1)*4/h)
			return a[0]<b[0] if ar==br else ar<br)
		output[name]=parts
		print(name," ",img.get_size()," ",JSON.stringify(parts))
	var f=FileAccess.open("res://data/appearance-atlases.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(output,"  ")+"\n")
	quit()
