shader_type canvas_item;

// O cenário distante perde mais cor que o resto do mapa quando o céu é cinzento.
uniform float grey_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 source = COLOR;
	float luminance = dot(source.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grey = vec3(luminance) * vec3(0.66, 0.72, 0.78);
	COLOR = vec4(mix(source.rgb, grey, grey_strength), source.a);
}
