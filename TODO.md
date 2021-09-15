# TODO list

* Show queue count in title tile, like search results.

* checkbox or something, indicating whether to auto-advance.

* Save to playlist from either search or queue.

* Add all features to app menus for discoverability.

* Allow filtering search results through a hook.  E.g., never listen to Coldplay.

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Little Credits or Help screen

* Documentation for Guile interface.

* Idea: backspace in search window takes you "up" a detail level if you've done a detail browse. AKA
  "show previous search results".  One approach could be to store the list of tracks returned by
  various searches, up to e.g. 10 ago.

* Make `?` highlight the currently-playing track in the search results, too.

## Things i can't do much about

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.
  https://github.com/librespot-org/librespot/issues/276,
  https://github.com/librespot-org/librespot/discussions/609

* Automatically switch audio output sink when using Sound.prefpane.
  https://github.com/RustAudio/rodio/issues/327

* very quick fade in / out when pausing? - maybe shorten the audio buffer in librespot? Turns out
  it's something i can't easily fix, because they also adjust audio volume per buffer chunk, grr.
