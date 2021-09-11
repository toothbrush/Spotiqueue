;;; BEGIN keybindings.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file contains code used to define custom keymaps and bindings.
(define-module (spotiqueue keybindings)
  #:use-module (spotiqueue key-constants)
  #:use-module (ice-9 format)
  #:use-module (ice-9 optargs))
(module-export-all! (current-module))

;;; struct key {
;;;   bool ctrl,  // C-
;;;   bool cmd,   // a.k.a. Hyper, H-
;;;   bool alt,   // a.k.a. Meta, M-
;;;   bool shift, // S-
;;;   symbol key
;;; }

;; I'm sure there's a nicer way to accomplish this, but for now it'll have to do.
(define <kbd>
  (make-vtable
   "pwpwpwpwpw" ; p = protected/boxed/SCM value, w = writable (deprecated/ignored)
   (lambda (kbd port)
     ;; I keep getting warnings, probably because (ice-9 format) isn't yet loaded at compile time... ^.-
     (format port "<<key> ~@[C-~]~@[H-~]~@[M-~]~@[S-~]~a>"
             (kbd-ctrl kbd)
             (kbd-cmd kbd)
             (kbd-alt kbd)
             (kbd-shift kbd)
             (hash-ref keycode->keysym (kbd-key kbd))))))

(define (kbd-ctrl kbd)
  (struct-ref kbd 0))
(define (kbd-cmd kbd)
  (struct-ref kbd 1))
(define (kbd-alt kbd)
  (struct-ref kbd 2))
(define (kbd-shift kbd)
  (struct-ref kbd 3))
(define (kbd-key kbd)
  (struct-ref kbd 4))

(define* (kbd keysym #:key (ctrl #f) (cmd #f) (alt #f) (shift #f))
  ;; Why doesn't hash-ref work here?!  Is it because symbols somehow "belong" to the module where
  ;; they've been defined?  Anyway, hashq-ref solves the issue for me, for now.
  (let ((keycode (hashq-ref keysym->keycode keysym)))
    (display keycode)
    (newline)
    (if keycode
        (make-struct/no-tail <kbd> ctrl cmd alt shift keycode)
        (raise-exception "Unknown key specified."))))

;; An example of how i would represent C-f in as-low-level a fashion as i can muster, for now.
;; Don't do this though, it's painful.  Mostly useful for constructing values in Swift-land.
(define example_C-f (make-struct/no-tail <kbd> #t #f #f #f 3))

;; An example of Alt-X
(define M-x (kbd 'ANSI_X #:alt #t))

;;; END keybindings.scm
