shader_type canvas_item;
void fragment() {
    vec2 q = abs(UV - 0.5) - vec2(0.44, 0.44);
    if (length(max(q, vec2(0.0))) > 0.06) discard;
    COLOR = texture(TEXTURE, UV);
}