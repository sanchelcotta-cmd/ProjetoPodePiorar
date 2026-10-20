shader_type canvas_item;

// Só a imagem perde a cor. Os textos e os ícones de status continuam legíveis.
void fragment() {
	vec4 pixel = texture(TEXTURE, UV) * COLOR;
	float gray = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray), pixel.a);
}
