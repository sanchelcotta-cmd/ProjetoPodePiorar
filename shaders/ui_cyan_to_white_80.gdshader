shader_type canvas_item;

// Janela de desfecho: reaproveita uielementx_00005, clareia apenas sua
// moldura ciana para branco e mantém o painel cinza a 80% de opacidade.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float is_cyan = step(0.55, pixel.g) * step(0.55, pixel.b)
		* (1.0 - step(0.55, pixel.r));
	COLOR = vec4(mix(pixel.rgb, vec3(1.0), is_cyan), pixel.a * 0.8);
}
