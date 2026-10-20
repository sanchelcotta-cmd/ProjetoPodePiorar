shader_type canvas_item;

// Mesmo bloco de pixels anteriormente usado no cenário. As franjas usam
// a transparência dos pixels vizinhos para vazar levemente da silhueta.
uniform float amount : hint_range(1.0, 32.0) = 4.0;
uniform vec4 left_fringe : source_color = vec4(1.0, 0.38, 0.72, 1.0);
uniform vec4 right_fringe : source_color = vec4(0.36, 1.0, 0.54, 1.0);
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
	vec4 base = textureLod(TEXTURE, sample_uv, 0.0) * vertex_tint;
	float grain = noise_hash(floor(UV / grid) + floor(TIME * 4.0));
	float line_wobble = step(0.92, noise_hash(vec2(floor(UV.y / grid.y), floor(TIME * 3.0))));
	vec2 shift = vec2(grid.x * (0.70 + line_wobble * 0.35), 0.0);
	float pink_alpha = textureLod(TEXTURE, sample_uv + shift, 0.0).a;
	float green_alpha = textureLod(TEXTURE, sample_uv - shift, 0.0).a;
	float fringe = (0.28 + grain * 0.16) * vertex_tint.a;
	vec3 rgb = base.rgb * base.a;
	float pink = max(pink_alpha - base.a, 0.0) * fringe;
	float green = max(green_alpha - base.a, 0.0) * fringe;
	rgb += left_fringe.rgb * pink + right_fringe.rgb * green;
	base.a = clamp(base.a + pink + green, 0.0, 1.0);
	base.rgb = rgb / max(base.a, 0.001);
	COLOR = base;
}
