;;; BEGIN paul-config.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This is an example of what would live in a user's config.  It is, in fact, the actual config
;;; file i use at the moment; i have a symlink:
;;;
;;; ~/.config/spotiqueue/init.scm -> ~/src/Spotiqueue/examples/paul-config.scm.
;;;
;;; I hope to use this file to collect a few neat ideas of things you can customise using the Guile
;;; bindings provided by Spotiqueue.

(define-module (spotiqueue paul-config)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 format)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 receive)
  #:use-module (spotiqueue base)
  #:use-module (spotiqueue keybindings)
  #:use-module (spotiqueue records)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9 gnu)
  #:use-module (texinfo string-utils))

;; Just some debug output when starting up, to make sure my file is loaded.  This ends up in stdout.
(format #t "guile ~s: Loading paul's config.~%" (module-name (current-module)))

;; <track> is the record type passed in to hook functions (see: Guile SRFI-9 Records
;; https://www.gnu.org/software/guile/manual/html_node/SRFI_002d9-Records.html).  I don't like the
;; way they're printed by default, so i override that:
(set-record-type-printer! <track>
                          (lambda (record port)
                            (format port
                                    "~a ~a - ~a (~a)"
                                    (track-uri record)
                                    (track-artist record)
                                    (track-title record)
                                    (track-album record))))

(define (paul:formatted-time)
  (strftime "[%a %e/%b/%Y %H:%M:%S %Z]" (localtime (current-time))))

;; A helper function to append a string to a file.  Copied from
;; https://git.sr.ht/~brown121407/f.scm/tree/master/item/f.scm
(define* (write-text path text #:key (append #f))
  (let ((file (open-file path (if append "a" "w"))))
    (put-string file text)
    (close-port file)))

(define my-homedir (getenv "HOME"))

;; I want to keep a log of tracks played.  This function will write each track to a file.  Later, we
;; use (add-hook! ..) to have Spotiqueue call it every time a new track starts.
(define (paul:player-started track)
  (begin
    (format #t "hey, a track has started: ~s\n" track)
    (if (defined? 'player:set-auto-advance)
        (player:set-auto-advance #t))   ; Reset auto-advance in case it was previously used to "stop after
                                        ; current".
    (write-text
     (string-append my-homedir "/spotiqueue-played.txt")
     (format #f "~a ~a\n" (paul:formatted-time) track)
     #:append #t)))

(define (paul:player-endoftrack track)
  (if (not (track? track))
      (error "eek, not a track!"))
  (begin
    (format #t "end of track: ~s~%" track)))

(define (paul:paused)
  (display "guile: Paused.\n"))

(define (paul:unpaused)
  (display "guile: Resumed/Unpaused.\n"))

;; You won't normally need to reset hooks, this just allows me to reload this file while Spotiqueue
;; is running and not have it keep appending a new copy of my function to the hooks-list.  For more
;; info on Hooks, see https://www.gnu.org/software/guile/manual/html_node/Hooks.html.
(reset-hook! player-endoftrack-hook)
(reset-hook! player-paused-hook)
(reset-hook! player-started-hook)
(reset-hook! player-unpaused-hook)
(reset-hook! selection-copied-hook)
(add-hook! player-endoftrack-hook paul:player-endoftrack)
(add-hook! player-paused-hook paul:paused)
(add-hook! player-started-hook paul:player-started)
(add-hook! player-unpaused-hook paul:unpaused)

;; Unbind a key i don't like, as an example:
(define-key queue-panel-map (kbd 'ForwardDelete) #nil)

;; The (kbd) procedure is a helper for binding keys.  At this point it'd probably be best to just
;; look at its definition in keybindings.scm.  Basically, you call it with one mandatory argument,
;; the symbol representing the keycap (see key-constants.scm for the full list) and optionally some
;; modifier flags.  Here are some examples:
;;
;; (kbd 'ANSI_Q) ; The `q' key, without modifiers
;; (kbd 'ANSI_Q #:alt #t) ; The `q' key, with "alt" (a.k.a. "option") modifier
;; (kbd 'Delete #:alt #t) ; Represents alt-backspace (on Mac keyboards, backspace is called the Delete key)
;; (kbd 'ForwardDelete #:cmd #t) ; Represents cmd-delete (on Mac keyboards, delete is called ForwardDelete)

;; TODO run hooks on a background thread.
;; Don't do this!  It'll make the UI freeze for 5 seconds.
;; (add-hook! selection-copied-hook (lambda (itms) (sleep 5)))

;; Slightly more involved example, where i am telling Hammerspoon (the `hs` command) to pop up a
;; message when i've copied some items.
;; TODO /usr/local/bin/hs isn't going to work on Apple M1.
(add-hook! selection-copied-hook
           (lambda (itms)
             (begin
               (let* ((message (format #f
                                       "💿 Copied ~r item~:p 🎧"
                                       (length itms)))
                      ;; Okay it's not great but i'm escaping quotes so that it remains valid Lua code...
                      (hs-alert (format #f "hs.alert.show(\"~a\")" (escape-special-chars message #\" #\\)))
                      (commands `(("/opt/homebrew/bin/hs" "-c" ,hs-alert))))
                 (format #t "~a~%" message)
                 (receive (from to pids) (pipeline commands)
                   (close to)
                   (close from))))))

;; TODO (window:maximise) ; to fill screen

;; Here's an example of something cool you can do with Guile: the full library is available to you.
;; If you want to be able to have remote clients connect to this Guile instance, you can do
;; something like the following.  I use it to make my media keys work, Hammerspoon does the equivalent of:
;;
;; nc localhost 37146 <<< "(player:next)"
(use-modules (system repl server))
(with-exception-handler
    (lambda (exn) (display "Couldn't bind port, skipping.\n"))
  (lambda ()
    (spawn-server (make-tcp-server-socket))) ; loopback:37146 by default
  #:unwind? #t)

;; This procedure finds the first queue position with a track with a different album name to the
;; currently-playing one.  NOTE there is a gotcha: if you forget to import SRFI-1, `list-index`
;; exists but.. doesn't do the right thing.
(define (paul:enqueue-after-current-album)
  (let ((search-selection   (search:get-selection))
        (current-track      (player:current-track)) ; may be #f
        (current-queue      (queue:get-tracks)))
    (format #t "Attempting top-insert after currently-playing album.~%")
    (cond
     ;; If there is nothing playing, just top-enqueue:
     ((not current-track)   (queue:insert-tracks search-selection 0))
     ;; We need to do work now, to find the first index for which album != current.
     (else
      (let* ((current-album (track-album current-track))
             (index         (list-index (lambda (x)
                                          (not
                                           (equal?
                                            (track-album x)
                                            current-album)))
                                        current-queue)))
        ;; If list-index returned #f, it means all queue items are of the same album.  In that case,
        ;; add search-selection to the very bottom of the queue.
        (if index
            (queue:insert-tracks search-selection index)
            (queue:insert-tracks search-selection (length current-queue))))))))

;; Shadow Cmd-Shift-H with our own top-enqueue, which is careful about currently-playing album:
(define-key search-panel-map (kbd 'ANSI_H #:cmd #t #:shift #t) paul:enqueue-after-current-album)

;; Cmd-R should restart the currently-playing track, if any.  Inspired by
;; https://github.com/toothbrush/Spotiqueue/pull/11, thanks @faaarmer!
(define (paul:restart-track)
  (format #t "Restarting current track.~%")
  (let ((current-track (player:current-track))) ;; `current-track' may be #f
    (when current-track ;; Only do things if we found a `current-track'.
      (queue:insert-tracks (list (track-uri current-track)) 0)
      (player:next))))
(define-key global-map (kbd 'ANSI_R #:cmd #t) paul:restart-track)

;; If you'd like to start from a clean slate, that is, don't restore previous track & playback
;; position on startup:
;;
;;    (if (defined? 'player:set-restore-playback)
;;        (player:set-restore-playback #f))

(format #t "Yay, unicode works 😊 📼 ~%")

;; Want to set preferences on startup?  Here's one example:
;; (player:set-auto-advance #f)

;;; END paul-config.scm
