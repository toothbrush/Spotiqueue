;;; BEGIN keybindings.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file contains code used to define custom keymaps and bindings.
(define-module (spotiqueue keybindings)
  #:use-module (spotiqueue key-constants)
  #:use-module ((ice-9 format) #:prefix i9:)
  #:use-module (ice-9 optargs))
(module-export-all! (current-module))

;;; struct key {
;;;   int  ANSI_key_code,
;;;   bool ctrl,  // C-
;;;   bool cmd,   // a.k.a. Hyper, H-
;;;   bool alt,   // a.k.a. Meta, M-
;;;   bool shift, // S-
;;; }

;; I'm sure there's a nicer way to accomplish this, but for now it'll have to do.
(define <kbd>
  (make-vtable
   "pwpwpwpwpw" ; p = protected/boxed/SCM value, w = writable (deprecated/ignored)
   (lambda (kbd port)
     ;; I keep getting warnings if i use a simple conditional ~@[string~], because `format'
     ;; considers that the argument hasn't been "used".  I wonder if there's a "accept but don't
     ;; use" way of doing things.  Oh well, this is fine for now.
     (i9:format port "<<key> ~:[~;C-~]~
                             ~:[~;H-~]~
                             ~:[~;M-~]~
                             ~:[~;S-~]~
                             ~a>"
                (kbd-ctrl kbd)
                (kbd-cmd kbd)
                (kbd-alt kbd)
                (kbd-shift kbd)
                (hash-ref keycode->keysym (kbd-keycode kbd))))))

(define (kbd? x)
  (and (struct? x)
       (eq? (struct-vtable x) <kbd>)))

(define (kbd-keycode kbd)
  (struct-ref kbd 0))
(define (kbd-ctrl kbd)
  (struct-ref kbd 1))
(define (kbd-cmd kbd)
  (struct-ref kbd 2))
(define (kbd-alt kbd)
  (struct-ref kbd 3))
(define (kbd-shift kbd)
  (struct-ref kbd 4))

(define* (kbd keysym #:key (ctrl #f) (cmd #f) (alt #f) (shift #f))
  ;; Why doesn't hash-ref work here?!  Is it because symbols somehow "belong" to the module where
  ;; they've been defined?  Anyway, hashq-ref solves the issue for me, for now.
  (let ((keycode (hashq-ref keysym->keycode keysym)))
    (if keycode
        (make-struct/no-tail <kbd> keycode ctrl cmd alt shift)
        (raise-exception "Unknown key specified."))))

;; An example of how i would represent C-f in as-low-level a fashion as i can muster, for now.
;; Don't do this though, it's painful.  Mostly useful for constructing values in Swift-land.
(define C-f (make-struct/no-tail <kbd> 3 #t #f #f #f))

;; An example of Alt-X
(define M-x (kbd 'ANSI_X #:alt #t))

;;; END keybindings.scm
