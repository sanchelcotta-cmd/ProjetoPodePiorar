shader_type canvas_item;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	if (pixel.a >= 0.01) {
		// Só o trevo verde vira rosa; os detalhes mantêm o desenho.
		if (pixel.g > pixel.r * 1.25 && pixel.g > pixel.b * 1.12 && pixel.g > 0.22) {
			float lightness = max(pixel.g, 0.35);
			pixel.rgb = vec3(min(1.0, lightness * 1.18),
				lightness * 0.47, lightness * 0.78);
		} else if (pixel.r > pixel.g * 1.16 && pixel.g > pixel.b * 1.08
				&& pixel.r > 0.12) {
			// Madeira um pouco mais clara, preservando textura e contraste.
			pixel.rgb = min(vec3(1.0), pixel.rgb * 1.36 + vec3(0.05, 0.035, 0.025));
		}
	}
	COLOR = pixel;
}
