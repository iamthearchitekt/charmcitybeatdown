extends RefCounted
var background:Texture2D=load("res://assets/harbor.png")
var water_material:ShaderMaterial

static func water_frame(t:float)->int:
	return int(floor(t*4.0))%2

func attach(parent:Node2D):
	var backdrop=Sprite2D.new()
	backdrop.texture=background
	backdrop.centered=false
	backdrop.scale=Vector2(1280.0/background.get_width(),720.0/background.get_height())
	backdrop.z_index=-20
	backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var shader=Shader.new()
	shader.code="""
shader_type canvas_item;
uniform int water_frame = 0;
void fragment() {
    vec2 p = UV;
    vec2 pixel = UV * vec2(1280.0,720.0);
    // Mask only unobstructed water; bollards, chains, boat and lamps stay fixed.
    float water = smoothstep(78.0,86.0,pixel.x)*(1.0-smoothstep(920.0,931.0,pixel.x));
    water *= smoothstep(388.0,394.0,pixel.y)*(1.0-smoothstep(436.0,443.0,pixel.y));
    // Exactly two fixed samples, alternating every quarter-second. No TIME warp.
    p.x += float(water_frame)*sin(UV.y*800.0)*0.0014*water;
    COLOR = texture(TEXTURE,p);
}
"""
	water_material=ShaderMaterial.new()
	water_material.shader=shader
	backdrop.material=water_material
	parent.add_child(backdrop)

func draw(canvas:Node2D,t:float):
	if water_material: water_material.set_shader_parameter("water_frame",water_frame(t))
	for i in 58:
		var x=fposmod(i*73.7-t*95,1360)-40
		var y=fposmod(i*51.3+t*350,720)
		canvas.draw_line(Vector2(x,y),Vector2(x-3,y+13),Color(.65,.78,.85,.10),1)
