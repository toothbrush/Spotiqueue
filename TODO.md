# TODO list

* When a user pastes URIs into queue,
  1. If they're all tracks, use fast batching retrieval (as currently
     implemented)
  2. If it's anything else or a mix, deal with them one-by-one.

* Allow pasting lists of:
  - [x] tracks
  - [ ] albums
  - [ ] playlists
  - won't support artist URI - just use search & browse!

## Other

* Automatically switch audio output sink when using Sound.prefpane - https://github.com/RustAudio/rodio/issues/327

* Media keys, globally

# Ideas

* Some sort of local "filter results" function (in search view).  Press "/" or something?
  present only items matching (regex) filter in at least one of their fields?


# Lower priority

* Save queue to .. NSUserDefaults? Text file?  On termination.

* When loading, if list of tracks found in NSUserDefaults, populate queue.

* Loved tracks retrieval
* Add/remove star

* Create playlist.. maybe? By default suggest name "Artist - Album"
  based on first selected item?  Or based on current queue?

* Deal with incorrect username/password gracefully.

* better logging framework, show messages in Console.app.

* FIX: blocking on get-all-albums for artist with many albums. Should
  be background job. Eg. search for beethoven, cmd-right twice in a
  row. Boom.

* Deal with user pasting `spotify:......` URI into search bar.

* Everywhere you can paste spotify URIs, consider allowing
  `https://open.spotify.com...` URLs, too.

* Create README with instructions for building, codesign, sparkle
  update, and especially the `ditto....` incantation and how `zip -r`
  breaks notarisation... https://developer.apple.com/forums/thread/677186

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.


* Pasting would be much easier if we didn't bother batching and dealt
  with each entry one-by-one... 🤔

* Little Credits or Help screen

* Why are the table column headers sometimes differently-coloured???

* I want a key shortcut to search for the currently playing song or
  album. Consider adding a menu item.

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.
