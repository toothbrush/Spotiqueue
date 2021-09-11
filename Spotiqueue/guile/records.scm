(define-module (spotiqueue records)
               #:use-module (srfi srfi-9)
               #:export
                 (<song> make-song song? song-uri song-title song-artist song-album song-duration))

(format #t "guile ~s: Loading Spotiqueue record definitions...~%" (module-name (current-module)))

;; Define a song representation for callbacks
(define-record-type <song>
  (_make-song uri title artist album duration)
  _song?
  (uri      _song-uri)
  (title    _song-title)
  (artist   _song-artist)
  (album    _song-album)
  (duration _song-duration))

;; OMG, we have these because you can't eval a syntax transformer from C??
(define (make-song uri title artist album duration)
  (_make-song uri title artist album duration))

(define (song? song) (_song? song))
(define (song-uri song) (_song-uri song))
(define (song-title song) (_song-title song))
(define (song-artist song) (_song-artist song))
(define (song-album song) (_song-album song))
(define (song-duration song) (_song-duration song))
