(decl ((in vec2 fragTexCoord)))
(decl ((in vec4 fragColor)))
(decl ((uniform float hue)))
(decl ((uniform float saturation)))
(decl ((uniform float value)))
(decl ((uniform float alpha)))
(decl ((out vec4 finalColor)))

;; Standard HSV->RGB, unrolled into six sectors with plain subtraction
;; instead of floor()/mod() — c-mera treats those as Lisp-level special
;; forms (they share names with CL functions) and type-errors on a live
;; GLSL expression node at shader-build time, not at GLSL compile time.
;; This mirrors edm-engine:hsv->rgb's i/f/p/q/t structure exactly, just
;; unrolled per sector instead of using FLOOR to pick one. HUE is
;; assumed pre-normalized to [0,1) by the caller.
(function main () -> void
  (decl ((vec3 color)))
  (decl ((float h6)))
  (decl ((float f)))
  (set h6 (* hue 6.0))
  (if (< h6 1.0)
      (progn
        (set f h6)
        (set color (vec3 value (* value (- 1.0 (* saturation (- 1.0 f)))) (* value (- 1.0 saturation)))))
      (if (< h6 2.0)
          (progn
            (set f (- h6 1.0))
            (set color (vec3 (* value (- 1.0 (* saturation f))) value (* value (- 1.0 saturation)))))
          (if (< h6 3.0)
              (progn
                (set f (- h6 2.0))
                (set color (vec3 (* value (- 1.0 saturation)) value (* value (- 1.0 (* saturation (- 1.0 f)))))))
              (if (< h6 4.0)
                  (progn
                    (set f (- h6 3.0))
                    (set color (vec3 (* value (- 1.0 saturation)) (* value (- 1.0 (* saturation f))) value)))
                  (if (< h6 5.0)
                      (progn
                        (set f (- h6 4.0))
                        (set color (vec3 (* value (- 1.0 (* saturation (- 1.0 f)))) (* value (- 1.0 saturation)) value)))
                      (progn
                        (set f (- h6 5.0))
                        (set color (vec3 value (* value (- 1.0 saturation)) (* value (- 1.0 (* saturation f))))))))))) 
  (set finalColor (vec4 color alpha)))
