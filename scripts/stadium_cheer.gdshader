shader_type canvas_item;

uniform int water_frame = 0;
uniform sampler2D gestures : filter_nearest, repeat_disable, hint_default_transparent;

void fragment() {
	vec4 scene = texture(TEXTURE, UV);
	vec4 cheer = texture(gestures, UV);
	COLOR = mix(scene, cheer, cheer.a * float(water_frame));
}
