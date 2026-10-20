shader_type canvas_item;

// Inspirado nos parâmetros da referência Animal Well; shader próprio para
// preservar o conteúdo de cada controle sem afetar botões interativos.
uniform float scan_line_fac = 1.2;
uniform float scan_line_width = 0.42;
uniform float linear_fac = 1.65;
uniform float nearest_fac = 0.42;
uniform float aberration = 0.001;
uniform bool terminal_text = false;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	vec2 displacement = vec2(aberration, 0.0);
	vec3 shifted = vec3(texture(TEXTURE, UV - displacement).r,
		base.g, texture(TEXTURE, UV + displacement).b) * COLOR.rgb;
	float stripe = step(fract(FRAGCOORD.y / 3.0), scan_line_width);
	vec3 combined = mix(shifted * linear_fac, base.rgb, nearest_fac);
	if (terminal_text) {
		float green_text = step(max(COLOR.r, COLOR.b) * 1.06, COLOR.g);
		combined = mix(vec3(0.94, 1.0, 0.94), vec3(0.45, 1.0, 0.60), green_text);
	}
	combined *= 1.0 - stripe * min(scan_line_fac * 0.14, 0.24);
	COLOR = vec4(clamp(combined, 0.0, 1.0), base.a);
}
