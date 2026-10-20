shader_type canvas_item;

// Clareia somente a arte rosa e mantém a moldura um pouco translúcida.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	COLOR = vec4(mix(pixel.rgb, vec3(1.0), 0.18), pixel.a * 0.8);
}
