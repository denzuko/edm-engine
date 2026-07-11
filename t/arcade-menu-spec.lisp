(in-package :edm-engine/tests)
(in-suite :edm-engine)

(test main-menu-select-wraps-around
  (let ((state (make-arcade-state)))
    (is (= 0 (arcade-state-main-menu-index state)))
    (arcade-select-previous-main-menu state)
    (is (= (1- (length +main-menu-items+)) (arcade-state-main-menu-index state)))
    (arcade-select-next-main-menu state)
    (is (= 0 (arcade-state-main-menu-index state)))))

(test drill-into-tables-enters-tables-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-main-menu-index state) 0)
    (arcade-drill-into-main-menu-selection state)
    (is (eq :tables (arcade-state-mode state)))))

(test drill-into-engine-options-enters-options-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-main-menu-index state) 1)
    (arcade-drill-into-main-menu-selection state)
    (is (eq :options (arcade-state-mode state)))))

(test drill-into-save-load-enters-save-load-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-main-menu-index state) 2)
    (arcade-drill-into-main-menu-selection state)
    (is (eq :save-load (arcade-state-mode state)))))

(test back-to-main-menu-resets-mode
  (let ((state (make-arcade-state)))
    (setf (arcade-state-mode state) :options)
    (arcade-back-to-main-menu state)
    (is (eq :main-menu (arcade-state-mode state)))))

(test escaping-from-playing-returns-to-tables-not-main-menu
  ;; "return the table menu (game selection)", not the top-level menu
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state)))
    (register-game "Stub" (lambda () :a-fake-game))
    (arcade-drill-into-main-menu-selection state) ; -> :tables
    (arcade-launch-selected state)
    (is (eq :playing (arcade-state-mode state)))
    (arcade-return-to-table-select state)
    (is (eq :tables (arcade-state-mode state)))
    (is (null (arcade-state-current-game state)))))

(test restart-current-relaunches-the-same-table-by-title
  (let ((edm-engine::*games* nil)
        (state (make-arcade-state))
        (calls 0))
    (register-game "Counted" (lambda () (incf calls) (list :instance calls)))
    (setf (arcade-state-mode state) :tables)
    (arcade-launch-selected state)
    (is (equal '(:instance 1) (arcade-state-current-game state)))
    (arcade-restart-current state)
    (is (equal '(:instance 2) (arcade-state-current-game state)))
    (is (eq :playing (arcade-state-mode state)))))
