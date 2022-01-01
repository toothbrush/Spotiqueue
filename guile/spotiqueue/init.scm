;;; BEGIN init.scm
;;;
;;; Copyright © 2021 paul at denknerd dot org
;;;
;;; This file is read by Spotiqueue as soon as it starts up.  It exposes some helpers and hooks for
;;; users.

(format #t "%load-path = ~s\n" %load-path)

;; If i want to use this module naming scheme i should have the source files in a folder called
;; `spotiqueue'.  Grr, there are already so many of those i'll just nest the Scheme files in
;; guile/spotiqueue i guess.  The Copy Files phase in Xcode can sort that out.

(define-module (spotiqueue init)
  #:use-module (ice-9 format)
  #:use-module (spotiqueue exceptions)
  #:use-module (spotiqueue functions)
  #:use-module (spotiqueue records)
  #:use-module (spotiqueue keybindings)
  #:declarative? #f)
(module-export-all! (current-module))

;; Syntax transformer to re-export all public defines from a given module from this module.  Grabbed
;; from https://www.mail-archive.com/bug-guile@gnu.org/msg10321.html
;;
;; What i want is, whenever someone imports (spotiqueue init), they should get whatever has been
;; defined in (spotiqueue functions), too.  The latter is the "phantom module" created in Swift-land
;; when Spotiqueue boots, exporting a few functions which are needed to sensibly be able to interact
;; with the music player.
(define-syntax re-export-public-interface
  (syntax-rules ()
    "Re-export the public interface of a module or modules. Invoked as
@code{(re-export-public-interface (mod1) (mod2) ...)}."
    ((_ (m0 m0* ...) (mn mn* ...) ...)
     (let ((iface (module-public-interface (current-module))))
       (define (r-e-p-i module)
         (cond-expand
          (guile-3
           (module-for-each
            (lambda (sym val)
              (hashq-set! (module-replacements iface) sym #t)
              (module-add! iface sym val))
            (resolve-interface module)))
          (else
           (module-use! iface (resolve-interface module)))))
       (r-e-p-i '(m0 m0* ...))
       (r-e-p-i '(mn mn* ...))
       ...))
    ((_)
     (syntax-error "must provide one or more module names"))
    ((_ m m* ...)
     (syntax-error "module names must look like lists"))))

(re-export-public-interface (spotiqueue functions))

;; The re-export thing should presumably be achievable with this snippet, from
;; https://debbugs.gnu.org/cgi/bugreport.cgi?bug=47084, and it does seem to work, except that i feel
;; like i can't really get my head around it.  Notably i don't understand the docstring of
;; `module-use!`, which simply states, "Add interface [the second arg] to the front of the use-list
;; of module [the first arg]. Both arguments should be module objects, and interface should very
;; likely be a module returned by resolve-interface."  Also, (current-module) always resolves to
;; (spotiqueue init), and not whatever is importing it...
;;
;;     (eval-when (expand load eval)
;;       (module-use! (module-public-interface (current-module))
;;                    (resolve-interface '(spotiqueue functions))))

(format #t "guile ~s: Loading Spotiqueue bootstrap config...~%" (module-name (current-module)))

;; Define the key maps
(define global-map (make-hash-table 10))
(define queue-panel-map (make-hash-table 10))
(define search-panel-map (make-hash-table 10))

;; Define the hooks.  The single argument is a <track> record.
(define player-started-hook (make-hook 1))
(define player-endoftrack-hook (make-hook 1))
(define player-paused-hook (make-hook 0))
(define player-unpaused-hook (make-hook 0))

;; The selection-copied hook will get a list of items copied as its single argument, each item
;; represented as string a (just as they'll end up on the pasteboard).
(define selection-copied-hook (make-hook 1))

(define (define-key map key action)
  (cond ((not (kbd? key))
         (raise-exception (format #f "~a is not a valid key symbol" key)))
        ((not (hash-table? map))
         (raise-exception (format #f "~a is not a hash-table" map)))
        ((not (or (procedure? action) (nil? action)))
         (raise-exception (format #f "~a is not a procedure" action)))
        (else
         (hash-set! map key action))))

(define-key global-map (kbd 'ANSI_F #:cmd #t)    window:focus-search-box)
(define-key global-map (kbd 'ANSI_L #:cmd #t)    window:focus-search-box)

(define-key queue-panel-map (kbd 'ANSI_X)        queue:delete-selected-tracks)
(define-key queue-panel-map (kbd 'ANSI_D)        queue:delete-selected-tracks)
(define-key queue-panel-map (kbd 'Delete)        queue:delete-selected-tracks)
(define-key queue-panel-map (kbd 'ForwardDelete) queue:delete-selected-tracks)

(define (flatten-track track)
  (cond ((track? track) (track-uri track))
        ((string? track) track)
        (else #nil)))

;; It's easier to ensure we're dealing with URIs only in Guile land.
(define (queue:set-tracks tracks)
  (queue:_set-tracks (map flatten-track tracks)))

;; This is stolen from https://www.programming-idioms.org/idiom/10/shuffle-a-list/2021/scheme, i wasn't feeling creative.
(define (shuffle-list list)
  (cond ((and (list? list)
              (positive? (length list)))
         (let ((item (list-ref list (random (length list)))))
           (cons item (shuffle-list (delete item list)))))
        (else list)))

(define (queue:shuffle)
  (let* ((tracks (queue:get-tracks))
         (shuffled (shuffle-list tracks)))
    (queue:set-tracks shuffled)))

(define-key global-map (kbd 'ANSI_S #:ctrl #t #:alt #t) queue:shuffle)

;;; END init.scm
