(display "guile(init.scm): Loading Spotiqueue bootstrap config...\n")

;; Import some library functions
(use-modules (ice-9 format)) ;; For a better (format ...)

;; Define the key maps
(define global-map)
(define queue-panel-map)
(define search-panel-map)

;; Define the hooks
(define player-started-hook (make-hook 1))
(define player-stopped-hook (make-hook 0))

;; This is what we want the API to look like, eventually:
;; (define-key queue-panel-map "x" 'queue:delete-selected-tracks)
;; (define-key queue-panel-map "H-k" 'queue:move-selected-tracks-up)

;; TODO add convenience functions for binding keys to procedures (we'll accept anything that evaluates to a Scheme procedure).

(assoc-set! queue-panel-map "x" 'queue:delete-selected-tracks)
(assoc-set! queue-panel-map "H-k" 'queue:move-selected-tracks-up)

(define (paul:player-stopped)
  (begin
    (display "hey, the song has stopped.")
    (newline)))

(define (paul:player-started song)
  (begin
    (format #t "hey, a song has started: ~s" song)
    (newline)))

(add-hook! player-started-hook paul:player-started)
(add-hook! player-stopped-hook paul:player-stopped)
