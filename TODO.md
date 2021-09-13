# TODO list

* checkbox or something, indicating whether to auto-advance.

* little transparent toaster telling you what you've copied to clipboard

* when regex-filtering then widening, no need to clobber user's selection.  can actually be useful
  for finding things in a long list.

* Add all features to app menus for discoverability.

* very quick fade in / out when pausing?

* Media keys, globally

* Create playlist.. maybe? By default suggest name "Artist - Album"
  based on first selected item?  Or based on current queue?

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Little Credits or Help screen

* Idea: backspace in search window takes you "up" a detail level if
  you've done a detail browse. AKA "show previous search results".

## Things i can't do much about

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.
  https://github.com/librespot-org/librespot/issues/276,
  https://github.com/librespot-org/librespot/discussions/609

* Automatically switch audio output sink when using Sound.prefpane.
  https://github.com/RustAudio/rodio/issues/327

* Make `?` highlight the currently-playing track in the search results, too.
