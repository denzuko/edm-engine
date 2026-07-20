#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
uniform float hue;
uniform float saturation;
uniform float value;
uniform float alpha;
out vec4 finalColor;

void main(void)
{
	vec3 color;
	float h6;
	float f;
	h6 = hue * 6.00000000e+0;
	if (h6 < 1.00000000e+0) {
		f = h6 - 0.00000000e+0;
		color = vec3(value, value * (1.00000000e+0 - (saturation * (1.00000000e+0 - f))), value * (1.00000000e+0 - saturation));
	}
	else if (h6 < 2.00000000e+0) {
		f = h6 - 1.00000000e+0;
		color = vec3(value * (1.00000000e+0 - (saturation * f)), value, value * (1.00000000e+0 - saturation));
	}
	else if (h6 < 3.00000000e+0) {
		f = h6 - 2.00000000e+0;
		color = vec3(value * (1.00000000e+0 - saturation), value, value * (1.00000000e+0 - (saturation * (1.00000000e+0 - f))));
	}
	else if (h6 < 4.00000000e+0) {
		f = h6 - 3.00000000e+0;
		color = vec3(value * (1.00000000e+0 - saturation), value * (1.00000000e+0 - (saturation * f)), value);
	}
	else if (h6 < 5.00000000e+0) {
		f = h6 - 4.00000000e+0;
		color = vec3(value * (1.00000000e+0 - (saturation * (1.00000000e+0 - f))), value * (1.00000000e+0 - saturation), value);
	}
	else {
		f = h6 - 5.00000000e+0;
		color = vec3(value, value * (1.00000000e+0 - saturation), value * (1.00000000e+0 - (saturation * f)));
	}
	finalColor = vec4(color, alpha);
}
