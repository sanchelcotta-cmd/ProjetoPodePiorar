shader_type canvas_item;

// Mantém o desenho de uielementx_00005, substituindo a linha ciano por preto.
// O fundo grafite quase opaco deixa o texto do status legível sobre o mapa.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float cyan = step(0.55, pixel.g) * step(0.55, pixel.b)
		* (1.0 - step(0.55, pixel.r));
	vec3 graphite = vec3(0.14, 0.15, 0.17);
	vec3 border = vec3(0.005, 0.005, 0.009);
	COLOR = vec4(mix(graphite, border, cyan), pixel.a * 0.95);
}
