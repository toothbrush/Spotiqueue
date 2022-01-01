;;; BEGIN exceptions.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file contains code for handling exceptions and showing the error message to the Spotiqueue
;;; GUI user.
(define-module (spotiqueue exceptions)
  #:use-module (ice-9 exceptions)
  #:use-module (ice-9 optargs)
  #:use-module (spotiqueue internal))
(module-export-all! (current-module))

(define (spot:with-exn-handler thunk)
  (with-exception-handler spot:handler thunk #:unwind? #t))

(define (spot:safe-run-hook hook args)
  (spot:with-exn-handler (lambda () (apply run-hook (cons hook args)))))

(define (spot:handler exn)
  (let ((message (cond (exception-with-message? exn) (exception-message exn)
                       (else "(no message)"))))
    (format #t "[spotiqueue exception] Raised: ~a~%" message)
    (player:alert "Guile Exception" (format #f "~a" message))))

(define (spot:safe-primitive-load file)
  (spot:with-exn-handler (lambda ()
                           (primitive-load file))))

;;; END exceptions.scm
