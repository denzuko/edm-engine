(decl ((in vec2 fragTexCoord)))
(decl ((in vec4 fragColor)))
(decl ((uniform int state)))
(decl ((uniform int outcome)))
(decl ((uniform float time)))
(decl ((out vec4 finalColor)))

;; state: 0=empty 1=gray 2=yellow 3=green
;; outcome: 0=none 1=win 2=lose 3=tie
;;
;; Functional tile colors use the Okabe-Ito colorblind-safe palette,
;; not the brand chrome palette — green/yellow is exactly the
;; distinction deuteranopia/protanopia struggle with, which is the
;; whole reason Okabe-Ito's orange/bluish-green pair exists. Values
;; match edm-engine:+okabe-ito-orange+/+okabe-ito-bluish-green+ and
;; +color-panel+/+color-brand-green+/+color-red+ (src/palette.lisp) —
;; c-mera reads its own DSL and can't dereference Lisp constants here,
;; so these are kept numerically identical by convention, not by
;; shared source.
(function main () -> void
  (decl ((vec3 color)))
  (if (== state 3)
      (set color (vec3 0.0 0.620 0.451))   ; okabe-ito bluish-green: correct
      (if (== state 2)
          (set color (vec3 0.902 0.624 0.0)) ; okabe-ito orange: present
          (if (== state 1)
              (set color (vec3 0.35 0.35 0.37)) ; neutral gray: absent
              (set color (vec3 0.051 0.067 0.090))))) ; +color-panel+: empty
  (decl ((float pulse)))
  (decl ((float gray)))
  (set pulse (+ 0.5 (* 0.5 (sin (* time 4.0)))))
  (set gray (dot color (vec3 0.299 0.587 0.114)))
  (if (== outcome 1)
      (set color (mix color (vec3 0.224 1.0 0.078) (* 0.35 pulse))) ; +color-brand-green+: win
      (if (== outcome 2)
          (set color (mix (vec3 (* gray 1.0) (* gray 0.35) (* gray 0.35)) color 0.6)) ; +color-red+-tinted desaturation: lose
          (if (== outcome 3)
              (set color (mix color (vec3 0.337 0.706 0.914) (* 0.3 pulse))) ; okabe-ito sky-blue: tie
              (set color color))))
  (set finalColor (vec4 color 1.0)))
