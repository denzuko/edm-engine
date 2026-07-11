#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform int state; // 0=empty 1=gray 2=yellow 3=green

out vec4 finalColor;

void main()
{
    vec3 color;
    if (state == 3) color = vec3(0.416, 0.667, 0.392);      // green
    else if (state == 2) color = vec3(0.788, 0.706, 0.345); // yellow
    else if (state == 1) color = vec3(0.471, 0.478, 0.494); // gray
    else color = vec3(0.086, 0.090, 0.102);                  // empty
    finalColor = vec4(color, 1.0);
}
