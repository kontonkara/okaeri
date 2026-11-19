// The theme's text color, and its dimmer one, as another: what's near either
// takes `to`, the dimmer at `dim` of its opacity, and the rest keeps its own.
// The edges of words, drawn a color for each third of a pixel, are known by
// their opacity: what words of that color covering as much of each third would
// leave. They keep how much of each third they cover.
// Built with Qt's qsb, from this folder:
//
//   qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o recolor.frag.qsb recolor.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
	mat4 qt_Matrix;
	float qt_Opacity;
	vec4 text;
	vec4 subtext;
	vec4 to;
	float dim;
};

layout(binding = 1) uniform sampler2D source;

// Whether a color is light enough to tell a third's cover by its light.
float light(vec3 from) {
	return step(0.3, max(max(from.r, from.g), from.b));
}

// How much of each third of the pixel words of color `from` cover.
vec3 cover(vec4 color, vec3 from) {
	return mix(vec3(color.a), clamp(color.rgb / max(from, vec3(0.001)), 0.0, 1.0), light(from));
}

// How much the pixel is of color `from`: near it, or an edge of words of it.
float like(vec4 color, vec3 from) {
	float near = 1.0 - smoothstep(0.06, 0.24, distance(color.rgb / color.a, from));
	float off = abs(dot(color.rgb / max(from, vec3(0.001)), vec3(1.0 / 3.0)) - color.a);
	return max(near, light(from) * step(off, 0.15 * color.a + 0.03));
}

void main() {
	vec4 color = texture(source, qt_TexCoord0);
	if (color.a > 0.0) {
		float ours = like(color, text.rgb);
		float dimmer = like(color, subtext.rgb) * (1.0 - ours);
		vec3 rgb = color.rgb * (1.0 - ours - dimmer) + to.rgb * (cover(color, text.rgb) * ours + cover(color, subtext.rgb) * dim * dimmer);
		color = vec4(rgb, color.a * (1.0 - dimmer + dimmer * dim));
	}
	fragColor = color * qt_Opacity;
}
