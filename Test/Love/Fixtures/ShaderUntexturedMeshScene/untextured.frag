vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen)
{
	return Texel(texture, uv) * color * vec4(0.25, 0.5, 1.0, 1.0);
}
