shader_type canvas_item;

// Dessatura só o cenário já desenhado. Esta camada fica abaixo do HUD,
// que mantém seus próprios contrastes e cores de informação/clique.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float desaturation : hint_range(0.0, 1.0) = 0.46;

void fragment() {
	vec3 original = texture(screen_texture, SCREEN_UV).rgb;
	float luminance = dot(original, vec3(0.299, 0.587, 0.114));
	vec3 muted = mix(original, vec3(luminance), desaturation);
	COLOR = vec4(muted * vec3(0.98, 0.99, 1.015), 1.0);
}
