shader_type canvas_item;

uniform int beacon_frame = 0;

void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	bool inside_lens = pixel.x >= 1454.0 && pixel.x < 1478.0 && pixel.y >= 355.0 && pixel.y < 376.0;
	if (inside_lens && beacon_frame != 0) {
		float amber = smoothstep(0.17, 0.45, paint.r - paint.b) * smoothstep(0.38, 0.78, paint.r);
		paint.rgb = mix(paint.rgb, vec3(1.0, 0.72, 0.22), amber * 0.22);
	}
	COLOR = paint;
}
