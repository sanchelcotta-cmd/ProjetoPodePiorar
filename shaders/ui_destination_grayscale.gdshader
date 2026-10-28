shader_type canvas_item;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	float gray = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(gray * 0.72), source.a);
}
