;;; BEGIN records.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file contains definitions of record types that are useful to users.  For example, when you
;;; subscribe to hooks, some of them will pass you a <track> object.

(define-module (spotiqueue records)
               #:use-module (srfi srfi-9))
(module-export-all! (current-module))

(format #t "guile ~s: Loading Spotiqueue record definitions...~%" (module-name (current-module)))

;; Define a track representation for callbacks
(define-record-type <track>
  (_make-track uri title artist album duration)
  _track?
  (uri      _track-uri)
  (title    _track-title)
  (artist   _track-artist)
  (album    _track-album)
  (duration _track-duration))

;; OMG, we have these because you can't eval a syntax transformer from C??
(define (make-track uri title artist album duration)
  (_make-track uri title artist album duration))

(define (track? track) (_track? track))
(define (track-uri track) (_track-uri track))
(define (track-title track) (_track-title track))
(define (track-artist track) (_track-artist track))
(define (track-album track) (_track-album track))
(define (track-duration track) (_track-duration track))

;;; END records.scm
