shader_type canvas_item;

// Adaptado de pixelate.gdshader, 2D FX Essentials, Dimension Almios (2026).
// Licença do pacote local: uso e adaptação em jogos permitidos.
uniform float amount : hint_range(1.0, 32.0) = 4.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 grid = TEXTURE_PIXEL_SIZE * amount;
	vec2 sample_uv = floor(UV / grid) * grid + grid * 0.5;
	COLOR = textureLod(TEXTURE, sample_uv, 0.0) * vertex_tint;
}
