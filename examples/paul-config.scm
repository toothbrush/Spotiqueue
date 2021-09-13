;;; This is an example of what would live in a user's config.
(use-modules (ice-9 textual-ports)
             (ice-9 format)
             (ice-9 popen)
             (ice-9 receive)
             (srfi srfi-9 gnu)
             (texinfo string-utils))
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

(define my-homedir (getenv "HOME"))

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
    (format #t "end of track: ~s~%" song)))

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

;; Unbind a key i don't like:
(define-key queue-panel-map (kbd 'Delete) #nil)

;; Don't do this!
;; TODO run hooks on a background thread.
;; (add-hook! selection-copied-hook (lambda (itms) (sleep 5)))

(add-hook! selection-copied-hook
           (lambda (itms)
             (begin
               (let* ((message (format #f
                                       "💿 Copied ~r item~:p 🎵"
                                       (length itms)))
                      ;; Okay it's not great but i'm escaping quotes so that it remains valid Lua code...
                      (hs-alert (format #f "hs.alert.show(\"~a\")" (escape-special-chars message #\" #\\)))
                      (commands `(("/usr/local/bin/hs" "-c" ,hs-alert))))
                 (format #t "~a~%" message)
                 (receive (from to pids) (pipeline commands)
                   (close to)
                   (close from))))))

;; TODO
;; (window:maximise) ; to fill screen

(use-modules (system repl server))
(with-exception-handler
    (lambda (exn) (display "Couldn't bind port, skipping.\n"))
  (lambda ()
    (spawn-server (make-tcp-server-socket))) ; loopback:37146 by default
  #:unwind? #t)

(format #t "yay unicode 😊 📼 ~%")
