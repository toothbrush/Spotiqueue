;;; This is an example of what would live in a user's config.
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

(define (paul:paused)
  (display "guile: Paused.\n"))

(define (paul:unpaused)
  (display "guile: Resumed/Unpaused.\n"))

(add-hook! player-started-hook paul:player-started)
(add-hook! player-endoftrack-hook paul:player-endoftrack)
(add-hook! player-paused-hook paul:paused)
(add-hook! player-unpaused-hook paul:unpaused)

;; TODO
;; (window:maximise) ; to fill screen
