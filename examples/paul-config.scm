;;; This is an example of what would live in a user's config.
(use-modules (ice-9 textual-ports)
             (ice-9 format)
             (srfi srfi-9 gnu))
(use-modules (spotiqueue records))
(format #t "guile ~s: Loading paul's config.~%" (module-name (current-module)))

(set-record-type-printer! <song>
                          (lambda (record port)
                            (format port
                                    "~a ~a - ~a (~a)"
                                    (song-uri record)
                                    (song-artist record)
                                    (song-title record)
                                    (song-album record))))

(define (paul:formatted-time)
  (strftime "[%a %e/%b/%Y %H:%M:%S %Z]" (localtime (current-time))))

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
     (format #f "~a ~a\n" (paul:formatted-time) song)
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

(reset-hook! player-endoftrack-hook)
(reset-hook! player-paused-hook)
(reset-hook! player-started-hook)
(reset-hook! player-unpaused-hook)
(add-hook! player-endoftrack-hook paul:player-endoftrack)
(add-hook! player-paused-hook paul:paused)
(add-hook! player-started-hook paul:player-started)
(add-hook! player-unpaused-hook paul:unpaused)

;; TODO
;; (window:maximise) ; to fill screen

(use-modules (system repl server))
(with-exception-handler
    (lambda (exn) (display "Couldn't bind port, skipping.\n"))
  (lambda ()
    (spawn-server (make-tcp-server-socket))) ; loopback:37146 by default
  #:unwind? #t)
