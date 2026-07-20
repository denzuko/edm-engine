#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
uniform int state;
uniform int outcome;
uniform float time;
out vec4 finalColor;

void main(void)
{
	vec3 color;
	if (state == 3)
		color = vec3(0.00000000e+0, 6.20000000e-1, 4.51000000e-1);
	else if (state == 2)
		color = vec3(9.02000000e-1, 6.24000000e-1, 0.00000000e+0);
	else if (state == 1)
		color = vec3(3.50000000e-1, 3.50000000e-1, 3.70000000e-1);
	else
		color = vec3(5.10000000e-2, 6.70000000e-2, 9.00000040e-2);
	float pulse;
	float gray;
	pulse = 5.00000000e-1 + (5.00000000e-1 * sin(time * 4.00000000e+0));
	gray = dot(color, vec3(2.99000000e-1, 5.87000000e-1, 1.14000000e-1));
	if (outcome == 1)
		color = mix(color, vec3(2.24000000e-1, 1.00000000e+0, 7.80000030e-2), 3.50000000e-1 * pulse);
	else if (outcome == 2)
		color = mix(vec3(gray * 1.00000000e+0, gray * 3.50000000e-1, gray * 3.50000000e-1), color, 6.00000000e-1);
	else if (outcome == 3)
		color = mix(color, vec3(3.37000000e-1, 7.06000000e-1, 9.14000000e-1), 3.00000000e-1 * pulse);
	else
		color = color;
	finalColor = vec4(color, 1.00000000e+0);
}
