shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 beam_tint : source_color = vec4(1.0, 0.87, 0.62, 1.0);
uniform float beam_opacity : hint_range(0.0, 1.0) = 0.20;

void fragment() {
	float down = clamp(UV.y, 0.0, 1.0);
	float half_width = mix(0.025, 0.49, pow(down, 0.78));
	float side_fade = max(0.025, half_width * 0.28);
	float across = 1.0 - smoothstep(half_width - side_fade,
		half_width, abs(UV.x - 0.5));
	float distance_fade = 1.0 - smoothstep(0.43, 1.0, down);
	float apex = smoothstep(0.0, 0.055, down);
	COLOR = vec4(beam_tint.rgb,
		beam_tint.a * across * distance_fade * apex * beam_opacity);
}
