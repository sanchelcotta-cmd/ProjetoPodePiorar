shader_type canvas_item;

uniform sampler2D scene_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform int mode = 0; // 0: padrão, 1: distorção, 2: Gameboy.
uniform vec3 gameboy_light : source_color = vec3(0.77, 0.89, 0.22);
uniform vec3 gameboy_dark : source_color = vec3(0.07, 0.20, 0.11);
uniform float scanline_strength = 0.24;
uniform float aberration = 0.0013;
uniform float palette_steps = 6.0;
uniform float dither_strength = 0.018;
uniform float pixel_size = 3.0;
uniform float distortion_strength = 0.0;

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float glitch = distortion_strength;
	float band = step(0.74, noise_hash(vec2(floor(FRAGCOORD.y / 14.0), floor(TIME * 22.0))));
	uv.x += band * glitch * sin(TIME * 43.0 + FRAGCOORD.y * 0.22) * 0.018;
	uv += vec2((noise_hash(floor(FRAGCOORD.xy / 36.0) + floor(TIME * 17.0)) - 0.5) * glitch * 0.008, 0.0);
	vec2 offset = vec2(aberration * (1.0 + glitch * 5.0), 0.0);
	vec3 color = vec3(
		texture(scene_texture, uv - offset).r,
		texture(scene_texture, uv).g,
		texture(scene_texture, uv + offset).b
	);
	if (mode == 2) {
		vec2 pixel = floor(FRAGCOORD.xy / max(pixel_size, 1.0));
		float luminosity = dot(color, vec3(0.299, 0.587, 0.114));
		float dither = (noise_hash(pixel) - 0.5) * 0.055;
		float level = floor(clamp(luminosity + dither, 0.0, 1.0) * 3.0 + 0.5) / 3.0;
		color = mix(gameboy_dark, gameboy_light, level);
	} else {
		float dither = (noise_hash(floor(FRAGCOORD.xy / max(pixel_size, 1.0))) - 0.5) * dither_strength;
		color = floor(clamp(color + dither, 0.0, 1.0) * palette_steps + 0.5) / palette_steps;
	}
	float scan = smoothstep(0.42, 0.5, abs(fract(FRAGCOORD.y / 3.0) - 0.5));
	color *= 1.0 - scanline_strength * scan;
	if (mode == 1) {
		color = mix(color, vec3(color.b, color.r, color.g), band * 0.35);
	}
	COLOR = vec4(clamp(color, 0.0, 1.0), 1.0);
}
