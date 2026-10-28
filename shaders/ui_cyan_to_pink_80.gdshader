shader_type canvas_item;

// Recolore só os traços cianos das artes novas. O fundo cinza mantém a cor
// original. A caixa fica quase opaca para manter o texto legível sobre o mapa.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float is_cyan = step(0.55, pixel.g) * step(0.55, pixel.b)
		* (1.0 - step(0.55, pixel.r));
	vec3 pink = vec3(0.996, 0.169, 0.592);
	COLOR = vec4(mix(pixel.rgb * 0.45, pink, is_cyan), pixel.a * 0.98);
}
