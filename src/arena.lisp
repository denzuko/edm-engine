(in-package :edm-engine)

(declaim (optimize (speed 3) (safety 3)))

(deftype sf-vector () '(simple-array single-float (*)))
(deftype gen-vector () '(simple-array (unsigned-byte 32) (*)))
(deftype bit-flags () '(simple-array bit (*)))

(defstruct (arena (:constructor %make-arena))
  "Fixed-capacity, contiguous component storage. No allocation after init;
entity slots are recycled via generation-checked handles."
  (capacity 0 :type fixnum)
  (alive (make-array 0 :element-type 'bit) :type bit-flags)
  (generations (make-array 0 :element-type '(unsigned-byte 32)) :type gen-vector)
  (pos-x (make-array 0 :element-type 'single-float) :type sf-vector)
  (pos-y (make-array 0 :element-type 'single-float) :type sf-vector)
  (vel-x (make-array 0 :element-type 'single-float) :type sf-vector)
  (vel-y (make-array 0 :element-type 'single-float) :type sf-vector)
  (free-list nil :type list))

(defun make-arena (capacity)
  (declare (fixnum capacity))
  (%make-arena :capacity capacity
               :alive (make-array capacity :element-type 'bit :initial-element 0)
               :generations (make-array capacity :element-type '(unsigned-byte 32)
                                                  :initial-element 0)
               :pos-x (make-array capacity :element-type 'single-float :initial-element 0.0)
               :pos-y (make-array capacity :element-type 'single-float :initial-element 0.0)
               :vel-x (make-array capacity :element-type 'single-float :initial-element 0.0)
               :vel-y (make-array capacity :element-type 'single-float :initial-element 0.0)
               :free-list (loop for i from (1- capacity) downto 0 collect i)))

(declaim (ftype (function (arena) (values handle &optional)) arena-spawn))
(defun arena-spawn (arena)
  "Allocate a slot from ARENA's free-list. Signals an error when exhausted."
  (let ((index (pop (arena-free-list arena))))
    (unless index (error "arena capacity exhausted"))
    (setf (sbit (arena-alive arena) index) 1)
    (handle index (aref (arena-generations arena) index))))

(declaim (ftype (function (arena handle) boolean) arena-despawn))
(defun arena-despawn (arena h)
  "Free H's slot and bump its generation, invalidating outstanding handles."
  (when (arena-alive-p arena h)
    (let ((i (handle-index h)))
      (setf (sbit (arena-alive arena) i) 0)
      (incf (aref (arena-generations arena) i))
      (push i (arena-free-list arena))
      t)))

(declaim (ftype (function (arena handle) boolean) arena-alive-p))
(defun arena-alive-p (arena h)
  (let ((i (handle-index h)))
    (and (< -1 i (arena-capacity arena))
         (= 1 (sbit (arena-alive arena) i))
         (= (handle-generation h) (aref (arena-generations arena) i)))))

(defmacro define-vec2-component (name x-slot y-slot)
  "Defines ARENA-NAME / ARENA-SET-NAME reading/writing X-SLOT, Y-SLOT vectors."
  (let ((getter (intern (format nil "ARENA-~A" name)))
        (setter (intern (format nil "ARENA-SET-~A" name))))
    `(progn
       (declaim (ftype (function (arena handle) (values single-float single-float)) ,getter))
       (defun ,getter (arena h)
         (let ((i (handle-index h)))
           (values (aref (,x-slot arena) i) (aref (,y-slot arena) i))))
       (declaim (ftype (function (arena handle single-float single-float) single-float) ,setter))
       (defun ,setter (arena h x y)
         (let ((i (handle-index h)))
           (setf (aref (,x-slot arena) i) x (aref (,y-slot arena) i) y))))))

(define-vec2-component "POSITION" arena-pos-x arena-pos-y)
(define-vec2-component "VELOCITY" arena-vel-x arena-vel-y)

(declaim (ftype (function (arena) list) arena-live-handles))
(defun arena-live-handles (arena)
  "Live handles, via a TRANSDUCERS pipeline over the slot range."
  (transducers:transduce
   (transducers:comp (transducers:take (arena-capacity arena))
                      (transducers:filter (lambda (i) (= 1 (sbit (arena-alive arena) i))))
                      (transducers:map (lambda (i) (handle i (aref (arena-generations arena) i)))))
   #'transducers:cons
   (transducers:ints 0)))
