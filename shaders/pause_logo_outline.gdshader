shader_type canvas_item;
render_mode unshaded;

uniform vec4 mint : source_color = vec4(0.33, 1.0, 0.90, 1.0);

void fragment() {
	float alpha = texture(TEXTURE, UV).a;
	vec2 one_pixel = TEXTURE_PIXEL_SIZE;
	float nearby = min(
		min(texture(TEXTURE, UV + vec2(one_pixel.x, 0.0)).a,
			texture(TEXTURE, UV - vec2(one_pixel.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, one_pixel.y)).a,
			texture(TEXTURE, UV - vec2(0.0, one_pixel.y)).a)
	);
	float edge = clamp((alpha - nearby) * 1.4, 0.0, 1.0);
	vec3 white = vec3(0.95, 0.98, 1.0);
	COLOR = vec4(mix(white, mint.rgb, edge * 0.62), alpha);
}
