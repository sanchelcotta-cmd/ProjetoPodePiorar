shader_type canvas_item;

// Adaptado de pixelate.gdshader, 2D FX Essentials, Dimension Almios (2026).
// Licença do pacote local: uso e adaptação em jogos permitidos.
uniform float amount : hint_range(1.0, 32.0) = 4.0;
uniform float palette_steps = 0.0;
uniform float distortion_strength = 0.0;
varying vec4 vertex_tint;

float noise_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 grid = TEXTURE_PIXEL_SIZE * amount;
	vec2 sample_uv = floor(UV / grid) * grid + grid * 0.5;
	float band = step(0.89, noise_hash(vec2(floor(UV.y / grid.y / 3.0), floor(TIME * 12.0))));
	sample_uv.x += band * grid.x * distortion_strength;
	vec4 pixel = textureLod(TEXTURE, sample_uv, 0.0) * vertex_tint;
	if (palette_steps > 1.0) {
		pixel.rgb = floor(pixel.rgb * palette_steps + 0.5) / palette_steps;
	}
	COLOR = pixel;
}
