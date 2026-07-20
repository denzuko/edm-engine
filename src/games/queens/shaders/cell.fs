#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
uniform float hue;
uniform int cursor;
uniform float time;
out vec4 finalColor;

void main(void)
{
	vec3 color;
	float h6;
	float f;
	float v;
	float pulse;
	pulse = 5.00000000e-1 + (5.00000000e-1 * sin(time * 6.00000000e+0));
	if (cursor == 1)
		v = 7.00000000e-1 + (3.00000000e-1 * pulse);
	else
		v = 8.20000000e-1;
	h6 = hue * 6.00000000e+0;
	if (h6 < 1.00000000e+0) {
		f = h6 - 0.00000000e+0;
		color = vec3(v, v * (1.00000000e+0 - (5.50000000e-1 * (1.00000000e+0 - f))), v * (1.00000000e+0 - 5.50000000e-1));
	}
	else if (h6 < 2.00000000e+0) {
		f = h6 - 1.00000000e+0;
		color = vec3(v * (1.00000000e+0 - (5.50000000e-1 * f)), v, v * (1.00000000e+0 - 5.50000000e-1));
	}
	else if (h6 < 3.00000000e+0) {
		f = h6 - 2.00000000e+0;
		color = vec3(v * (1.00000000e+0 - 5.50000000e-1), v, v * (1.00000000e+0 - (5.50000000e-1 * (1.00000000e+0 - f))));
	}
	else if (h6 < 4.00000000e+0) {
		f = h6 - 3.00000000e+0;
		color = vec3(v * (1.00000000e+0 - 5.50000000e-1), v * (1.00000000e+0 - (5.50000000e-1 * f)), v);
	}
	else if (h6 < 5.00000000e+0) {
		f = h6 - 4.00000000e+0;
		color = vec3(v * (1.00000000e+0 - (5.50000000e-1 * (1.00000000e+0 - f))), v * (1.00000000e+0 - 5.50000000e-1), v);
	}
	else {
		f = h6 - 5.00000000e+0;
		color = vec3(v, v * (1.00000000e+0 - 5.50000000e-1), v * (1.00000000e+0 - (5.50000000e-1 * f)));
	}
	finalColor = vec4(color, 1.00000000e+0);
}
