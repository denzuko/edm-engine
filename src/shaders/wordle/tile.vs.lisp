(decl ((in vec3 vertexPosition)))
(decl ((in vec2 vertexTexCoord)))
(decl ((in vec4 vertexColor)))
(decl ((uniform mat4 mvp)))
(decl ((out vec2 fragTexCoord)))
(decl ((out vec4 fragColor)))

(function main () -> void
  (set fragTexCoord vertexTexCoord)
  (set fragColor vertexColor)
  (set gl_Position (* mvp (vec4 vertexPosition 1.0))))
