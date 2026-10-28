shader_type canvas_item;

// Chiado discreto só no fundo: painéis e botões permanecem foscos e legíveis.
void fragment() {
    vec2 cell = floor(UV * vec2(900.0, 510.0));
    float flicker = floor(TIME * 9.0);
    float grain = fract(sin(dot(cell + flicker, vec2(12.9898, 78.233))) * 43758.5453);
    float shade = 0.025 + grain * 0.027;
    COLOR = vec4(vec3(shade, shade + 0.006, shade + 0.012), 1.0);
}
