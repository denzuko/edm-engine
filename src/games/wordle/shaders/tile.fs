#version 330

in vec2 fragTexCoord;
in vec4 fragColor;
uniform int state;
out vec4 finalColor;

void main(void)
{
	vec3 color;
	if (state == 3)
		color = vec3(4.16000000e-1, 6.67000000e-1, 3.92000000e-1);
	else if (state == 2)
		color = vec3(7.88000000e-1, 7.06000000e-1, 3.45000000e-1);
	else if (state == 1)
		color = vec3(4.71000000e-1, 4.78000000e-1, 4.94000000e-1);
	else
		color = vec3(8.60000000e-2, 9.00000040e-2, 1.02000000e-1);
	finalColor = vec4(color, 1.00000000e+0);
}
