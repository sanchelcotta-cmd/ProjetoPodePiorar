shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.55;

float sparkle(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 original = texture(screen_texture, uv).rgb;
	float phase = TIME * 6.0 + uv.x * 7.0 + uv.y * 5.0;
	vec3 rainbow = 0.5 + 0.5 * cos(phase + vec3(0.0, 2.094, 4.188));
	float beat = 0.55 + 0.05 * sin(TIME * 13.0);
	vec3 color = mix(original, rainbow, strength * beat / 0.55);
	// Pontos brancos flutuantes: pequenas luzes de vagalume, sem capturar cliques.
	vec2 grid = uv * vec2(24.0, 14.0);
	vec2 cell = floor(grid);
	vec2 center = vec2(sparkle(cell), sparkle(cell + 19.0));
	center.y += 0.20 * sin(TIME * 1.8 + sparkle(cell + 7.0) * 6.28);
	float luminous = 1.0 - smoothstep(0.035, 0.15, length(fract(grid) - center));
	luminous *= step(0.91, sparkle(cell + 43.0));
	color = mix(color, vec3(1.0), luminous * 0.75);
	COLOR = vec4(color, 1.0);
}
