;;; This is an example of what would live in a user's config.
(use-modules (ice-9 textual-ports))

(define* (write-text path text #:key (append #f))
  (let ((file (open-file path (if append "a" "w"))))
    (put-string file text)
    (close-port file)))

(define my-homedir (spotiqueue:get-homedir))

(define (paul:player-started song)
  (if (not (song? song))
      (error "eek, not a song!"))
  (begin
    (format #t "hey, a song has started: ~s\n" song)
    (write-text
     (string-append my-homedir "/spotiqueue-played.txt")
     (format #f "~a\n" song)
     #:append #t)))

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

(add-hook! player-endoftrack-hook paul:player-endoftrack)
(add-hook! player-paused-hook paul:paused)
(add-hook! player-started-hook paul:player-started)
(add-hook! player-unpaused-hook paul:unpaused)

;; TODO
;; (window:maximise) ; to fill screen
