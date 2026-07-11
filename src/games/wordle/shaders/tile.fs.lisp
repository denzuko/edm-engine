(decl ((in vec2 fragTexCoord)))
(decl ((in vec4 fragColor)))
(decl ((uniform int state)))
(decl ((out vec4 finalColor)))

;; state: 0=empty 1=gray 2=yellow 3=green
(function main () -> void
  (decl ((vec3 color)))
  (if (== state 3)
      (set color (vec3 0.416 0.667 0.392))
      (if (== state 2)
          (set color (vec3 0.788 0.706 0.345))
          (if (== state 1)
              (set color (vec3 0.471 0.478 0.494))
              (set color (vec3 0.086 0.090 0.102)))))
  (set finalColor (vec4 color 1.0)))
