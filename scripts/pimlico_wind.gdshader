shader_type canvas_item;

uniform int wind_frame = 0;

float fabric_lift(vec2 pixel, vec4 bounds, float wave_offset) {
	if (pixel.x <= bounds.x || pixel.x >= bounds.z || pixel.y <= bounds.y || pixel.y >= bounds.w) {
		return 0.0;
	}
	vec2 relative = (pixel - bounds.xy) / (bounds.zw - bounds.xy);
	float loose_end = smoothstep(0.0, 0.7, relative.x) * (1.0 - smoothstep(0.90, 1.0, relative.x));
	float fade = smoothstep(0.0, 0.18, relative.y) * (1.0 - smoothstep(0.80, 1.0, relative.y));
	return round((10.0 + 5.0 * sin(relative.x * 8.0 + wave_offset)) * loose_end * fade);
}

void fragment() {
	vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
	float lift = 0.0;
	if (wind_frame != 0) {
		// Each rectangle begins past its pole. The fastened edge stays in place.
		lift += fabric_lift(pixel, vec4(440.0, 67.0, 584.0, 145.0), 0.0);
		lift += fabric_lift(pixel, vec4(890.0, 105.0, 1021.0, 183.0), 0.9);
		lift += fabric_lift(pixel, vec4(1245.0, 151.0, 1364.0, 221.0), 1.8);
	}
	COLOR = texture(TEXTURE, UV + vec2(0.0, lift * TEXTURE_PIXEL_SIZE.y));
}
