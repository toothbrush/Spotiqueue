;;; BEGIN init.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file is read by Spotiqueue as soon as it starts up.  It exposes some helpers and hooks for
;;; users.

(display "guile(init.scm): Loading Spotiqueue bootstrap config...\n")

;; Import some library functions
(use-modules (ice-9 format)) ;; For a better (format ...)
(use-modules (srfi srfi-9)) ;; For Records, https://www.gnu.org/software/guile/manual/html_node/SRFI_002d9-Records.html

;; Define a song representation for callbacks
(define-record-type <song>
  (make-song uri title artist album duration)
  song?
  (uri      song-name)
  (title    song-age)
  (artist   song-salary)
  (album    song-album)
  (duration song-duration))

(define (_make-song uri title artist album duration)
  "OMG, we have this because you can't eval a macro, and make-song is a macro."
  (make-song uri title artist album duration))

;; Define the key maps
(define global-map)
(define queue-panel-map)
(define search-panel-map)

;; Define the hooks
(define player-started-hook (make-hook 1))
(define player-endoftrack-hook (make-hook 1))
(define player-stopped-hook (make-hook 0))

;; This is what we want the API to look like, eventually:
;; (define-key queue-panel-map "x" 'queue:delete-selected-tracks)
;; (define-key queue-panel-map "H-k" 'queue:move-selected-tracks-up)

;; TODO add convenience functions for binding keys to procedures (we'll accept anything that evaluates to a Scheme procedure).

(assoc-set! queue-panel-map "x" 'queue:delete-selected-tracks)
(assoc-set! queue-panel-map "H-k" 'queue:move-selected-tracks-up)


;;; END init.scm

;;; This is what would live in a user's config.
(define (paul:player-stopped)
  (begin
    (display "hey, the song has stopped.")
    (newline)))

(define (paul:player-started song)
  (if (not (song? song))
      (error "eek, not a song!"))
  (begin
    (format #t "hey, a song has started: ~s" song)
    (newline)))

(define (paul:player-endoftrack song)
  (if (not (song? song))
      (error "eek, not a song!"))
  (begin
    (format #t "end of track: ~s" song)
    (newline)))

(add-hook! player-started-hook paul:player-started)
(add-hook! player-endoftrack-hook paul:player-endoftrack)
(add-hook! player-stopped-hook paul:player-stopped)
