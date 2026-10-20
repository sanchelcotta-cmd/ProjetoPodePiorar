shader_type canvas_item;

uniform vec4 accent : source_color = vec4(0.16, 0.88, 0.98, 1.0);

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	bool border = pixel.r > 0.75 && pixel.b > 0.35 && pixel.g < 0.5;
	COLOR = border
		? vec4(accent.rgb, pixel.a * accent.a)
		: vec4(0.025, 0.039, 0.048, pixel.a * 0.82);
}
