;;;; tools/generate-chrome-shader.lisp
;;;;
;;;; Generates src/shaders/chrome.fs.lisp from tools/hsv-shader-lib.lisp's
;;;; shared HSV->RGB generator — a thin consumer, not a second copy of
;;;; the hexagonal-cone construction. hue/saturation/value/alpha here
;;;; are plain uniform references; see generate-queens-shader.lisp
;;;; for a caller that passes computed expressions instead.
;;;;
;;;; Usage: sbcl --script tools/generate-chrome-shader.lisp

(load (merge-pathnames "hsv-shader-lib.lisp" *load-pathname*))

(defparameter *chrome-fs-forms*
  `((decl ((in vec2 |fragTexCoord|)))
    (decl ((in vec4 |fragColor|)))
    (decl ((uniform float hue)))
    (decl ((uniform float saturation)))
    (decl ((uniform float value)))
    (decl ((uniform float alpha)))
    (decl ((out vec4 |finalColor|)))
    (function main () -> void
      (decl ((vec3 color)))
      (decl ((float h6)))
      (decl ((float f)))
      ,@(hsv-color-forms 'hue 'color 'value 'saturation 'h6 'f)
      (set |finalColor| (vec4 color alpha)))))

(write-generated-shader-source
 "src/shaders/chrome.fs.lisp"
 *chrome-fs-forms*
 :generator-script "tools/generate-chrome-shader.lisp"
 :description-lines
 '("Standard HSV->RGB, via tools/hsv-shader-lib.lisp's shared generator —"
   "not a private copy of the hexagonal-cone construction. MOD/FLOOR"
   "avoided in that library — c-mera treats those as Lisp-level special"
   "forms (CL-homonym names), not GLSL passthroughs; they type-error on a"
   "live GLSL expression node at shader-build time."))
