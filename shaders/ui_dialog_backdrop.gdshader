shader_type canvas_item;

// Desfoque discreto (9% de uma amostra suavizada) e leve escurecimento.
// Só é desenhado enquanto uma confirmação está aberta.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 sharp = textureLod(screen_texture, SCREEN_UV, 0.0).rgb;
	vec3 soft = textureLod(screen_texture, SCREEN_UV, 2.0).rgb;
	COLOR = vec4(mix(sharp, soft, 0.09) * 0.95, 1.0);
}
