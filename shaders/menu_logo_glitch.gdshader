shader_type canvas_item;
render_mode unshaded;

// 0: tres P e i; 1: previa completa; 2: troca ? -> !; 3: oficial;
// 4: glitch breve da logo oficial.
uniform int phase = 0;
uniform float effect_time = 0.0;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 palette_a : source_color = vec4(0.22, 0.85, 0.94, 1.0);
uniform vec4 palette_b : source_color = vec4(0.45, 1.0, 0.88, 1.0);
uniform vec4 palette_c : source_color = vec4(1.0, 0.40, 0.69, 1.0);

float in_rect(vec2 point, vec4 bounds) {
	return step(bounds.x, point.x) * step(bounds.y, point.y)
		* step(point.x, bounds.z) * step(point.y, bounds.w);
}

float noise(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float first_letters = max(
		max(in_rect(UV, vec4(0.230, 0.078, 0.310, 0.244)),
			in_rect(UV, vec4(0.230, 0.222, 0.425, 0.565))),
		max(in_rect(UV, vec4(0.026, 0.435, 0.242, 0.914)),
			in_rect(UV, vec4(0.238, 0.540, 0.313, 0.914)))
	);
	float swap_region = max(in_rect(UV, vec4(0.300, 0.615, 0.472, 0.910)),
		in_rect(UV, vec4(0.810, 0.378, 0.995, 0.910)));
	float affected = phase == 0 ? first_letters : phase == 2 ? swap_region : phase == 4 ? 1.0 : 0.0;
	float strength = intensity * affected;
	if (strength > 0.0) {
		float tick = floor(effect_time * 26.0);
		float stripe = floor(UV.y * 75.0);
		float jitter = (noise(vec2(stripe, tick)) - 0.5) * 0.025 * strength;
		vec2 shifted = clamp(UV + vec2(jitter, 0.0), vec2(0.001), vec2(0.999));
		vec4 displaced = texture(TEXTURE, shifted);
		float scanline = noise(vec2(stripe * 0.37, tick));
		source = mix(source, displaced, strength * (0.32 + 0.34 * scanline));
		float split = 0.0022 * strength;
		vec4 left = texture(TEXTURE, clamp(shifted + vec2(split, 0.0), vec2(0.001), vec2(0.999)));
		vec4 right = texture(TEXTURE, clamp(shifted - vec2(split, 0.0), vec2(0.001), vec2(0.999)));
		source.r = mix(source.r, left.r, strength * 0.45);
		source.b = mix(source.b, right.b, strength * 0.45);
		if (phase == 4) {
			float choice = floor(noise(vec2(stripe, tick * 0.73)) * 3.0);
			vec3 tint = choice < 1.0 ? palette_a.rgb : choice < 2.0 ? palette_b.rgb : palette_c.rgb;
			source.rgb = mix(source.rgb, tint, 0.58 * strength * scanline);
		}
		source.rgb += vec3(0.07 * strength * step(0.92, scanline));
	}
	if (phase == 0) {
		source.a *= first_letters;
	}
	COLOR = source;
}
