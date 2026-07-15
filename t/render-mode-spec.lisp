(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test render-mode-defaults-to-gpu
  (is (eq :gpu *render-mode*)))

(test render-mode-toggle-switches-between-gpu-and-cpu
  (let ((*render-mode* :gpu))
    (toggle-render-mode)
    (is (eq :cpu *render-mode*))
    (toggle-render-mode)
    (is (eq :gpu *render-mode*))))
