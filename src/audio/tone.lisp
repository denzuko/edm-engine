(in-package :edm-engine/audio)

(declaim (optimize (speed 3) (safety 3)))

(deftype waveform () '(member :sine :square :triangle :sawtooth))

(declaim (ftype (function (waveform single-float single-float &key (:sample-rate fixnum) (:amplitude single-float))
                          (simple-array (signed-byte 16) (*)))
                generate-samples))
(defun generate-samples (waveform frequency duration-seconds &key (sample-rate 44100) (amplitude 0.5))
  "Generates SAMPLE-RATE * DURATION-SECONDS samples of WAVEFORM at
FREQUENCY Hz, on the fly — no pre-recorded audio anywhere in this
engine. AMPLITUDE is 0.0-1.0."
  (let* ((n (round (* duration-seconds sample-rate)))
         (samples (make-array n :element-type '(signed-byte 16))))
    (dotimes (i n samples)
      (let* ((tm (/ i (float sample-rate 1.0)))
             (phase (mod (* frequency tm) 1.0))
             (value (ecase waveform
                      (:sine (sin (* 2 pi phase)))
                      (:square (if (< phase 0.5) 1.0 -1.0))
                      (:triangle (- (* 4.0 (abs (- phase 0.5))) 1.0))
                      (:sawtooth (- (* 2.0 phase) 1.0)))))
        (setf (aref samples i) (round (* amplitude value 32767)))))))

(defun u32-le (n) (list (ldb (byte 8 0) n) (ldb (byte 8 8) n) (ldb (byte 8 16) n) (ldb (byte 8 24) n)))
(defun u16-le (n) (list (ldb (byte 8 0) n) (ldb (byte 8 8) n)))
(defun ascii (s) (map 'list #'char-code s))

(declaim (ftype (function ((simple-array (signed-byte 16) (*)) fixnum) (array (unsigned-byte 8) (*)))
                wav-bytes-for-samples))
(defun wav-bytes-for-samples (samples sample-rate)
  "Wraps SAMPLES (mono 16-bit PCM) in a canonical 44-byte RIFF/WAVE
header, ready for LOAD-WAVE-FROM-MEMORY."
  (let* ((n (length samples))
         (data-size (* 2 n))
         (header (append (ascii "RIFF") (u32-le (+ 36 data-size)) (ascii "WAVE")
                          (ascii "fmt ") (u32-le 16) (u16-le 1) (u16-le 1)
                          (u32-le sample-rate) (u32-le (* sample-rate 2)) (u16-le 2) (u16-le 16)
                          (ascii "data") (u32-le data-size)))
         (result (make-array (+ 44 data-size) :element-type '(unsigned-byte 8))))
    (loop for b in header for i from 0 do (setf (aref result i) b))
    (dotimes (i n result)
      (let ((u (logand (aref samples i) #xFFFF)))
        (setf (aref result (+ 44 (* 2 i))) (ldb (byte 8 0) u)
              (aref result (+ 44 (* 2 i) 1)) (ldb (byte 8 8) u))))))
