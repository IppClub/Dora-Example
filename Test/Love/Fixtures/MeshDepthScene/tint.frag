extern vec3 tint;
extern number intensity;
extern Image mask;
extern Image layers[2];
extern int mode;
extern uint flags;
extern bool enabled;
extern float weights[3];
extern ivec2 offsets[2];
extern vec3 palette[2];
extern mat2 basis;
extern mat3 frames[2];
extern mat4 transforms[2];

vec4 effect(vec4 color, Image texture, vec2 textureCoords, vec2 screenCoords)
{
	bool basisValid = basis[0][1] == 3.0 && basis[1][0] == 2.0;
	bool framesValid = frames[mode][0][1] == 8.0 && frames[mode][2][0] == 3.0;
	bool transformsValid = transforms[mode][0][1] == 5.0 && transforms[mode][1][0] == 2.0;
	bool valid = enabled && flags == 4000000000u
		&& offsets[mode] == ivec2(2, -2) && basisValid && framesValid && transformsValid;
	vec3 selected = palette[mode] * weights[mode] * tint * intensity;
	return valid ? Texel(mask, textureCoords)
		* Texel(layers[mode], textureCoords + vec2(0.0, 0.0))
		* vec4(selected, 1.0) * color
		: vec4(1.0, 0.0, 1.0, 1.0);
}
