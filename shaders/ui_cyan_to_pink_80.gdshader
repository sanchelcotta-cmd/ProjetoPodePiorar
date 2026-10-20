shader_type canvas_item;

// Recolore só os traços cianos das artes novas. O fundo cinza mantém a cor
// original, e toda a caixa fica a 80% sem editar o PNG de origem.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float is_cyan = step(0.55, pixel.g) * step(0.55, pixel.b)
		* (1.0 - step(0.55, pixel.r));
	vec3 pink = vec3(0.996, 0.169, 0.592);
	COLOR = vec4(mix(pixel.rgb, pink, is_cyan), pixel.a * 0.8);
}
