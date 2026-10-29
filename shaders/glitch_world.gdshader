shader_type canvas_item;

// Ruído translúcido: não lê a tela. No viewport embutido, uma captura de
// tela vazia podia transformar o antigo pós-processamento em branco sólido.
uniform int mode = 0; // 0: padrão, 1: distorção, 2: pulso Gameboy.
uniform vec3 gameboy_light : source_color = vec3(0.77, 0.89, 0.22);
uniform vec3 gameboy_dark : source_color = vec3(0.07, 0.20, 0.11);
uniform float distortion_strength = 0.0;

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float row = floor(FRAGCOORD.y / 3.0);
	float scan = 1.0 - smoothstep(0.08, 0.42, fract(FRAGCOORD.y / 3.0));
	float grain = noise_hash(floor(FRAGCOORD.xy / 24.0) + floor(TIME * 9.0));
	float band = step(0.83, noise_hash(vec2(floor(row / 5.0), floor(TIME * 17.0))));
	vec3 tint = vec3(0.08, 0.28, 0.21);
	float alpha = 0.025 + scan * 0.025 + grain * 0.018;
	if (mode == 1) {
		tint = mix(tint, vec3(0.42, 0.12, 0.34), band);
		alpha += distortion_strength * (0.02 + band * 0.10);
	} else if (mode == 2) {
		tint = mix(gameboy_dark, gameboy_light, 0.45 + grain * 0.24);
		alpha = 0.20 + scan * 0.045;
	}
	COLOR = vec4(tint, clamp(alpha, 0.0, 0.30));
}
