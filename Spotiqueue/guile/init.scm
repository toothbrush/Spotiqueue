;;; BEGIN init.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file is read by Spotiqueue as soon as it starts up.  It exposes some helpers and hooks for
;;; users.

(display "guile(init.scm): Loading Spotiqueue bootstrap config...")
(newline)

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
(define player-paused-hook (make-hook 0))
(define player-unpaused-hook (make-hook 0))

;; This is what we want the API to look like, eventually:
;; (define-key queue-panel-map "x" 'queue:delete-selected-tracks)
;; (define-key queue-panel-map "H-k" 'queue:move-selected-tracks-up)

;; TODO add convenience functions for binding keys to procedures (we'll accept anything that evaluates to a Scheme procedure).

(assoc-set! queue-panel-map "x" 'queue:delete-selected-tracks)
(assoc-set! queue-panel-map "H-k" 'queue:move-selected-tracks-up)

;; Find and load a user's config, in ~/.config/spotiqueue/init.scm, if it exists.  Finding $HOME in
;; Guile-proper is a bit annoying, because we need to rely on it managing to work out who we're
;; running as, and fishing the info out of /etc/passwd (!).  This works well when running Guile in a
;; terminal, but fails in a graphical app.  Likely $UID isn't set?  Anyway we just lean on
;; Objective-C to give us the user's home here.
(let* ((homedir (spotiqueue:get-homedir))
       (user-config-file (string-append homedir "/.config/spotiqueue/init.scm")))
  (begin
    (format #t "Looking for user config in: ~a... " user-config-file)
    (if (stat user-config-file #f)
        (begin
          (display "found!")
          (newline)
          (load user-config-file))
        (begin
          (display "FAIL")
          (newline)
          (display "User-config file doesn't exist, skipping.")
          (newline)))))

;;; END init.scm
