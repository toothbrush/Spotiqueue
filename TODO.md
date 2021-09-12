# TODO list

* checkbox or something, indicating whether to auto-advance.

* little transparent toaster telling you what you've copied to clipboard

* Add all features to app menus for discoverability.

* very quick fade in / out when pausing?

* Media keys, globally - meh use Hammerspoon

* Create playlist:

    * Initially simply create from queue contents, but it'd be nice to have a way (from Guile) to
      create a playlist and add particular songs to it.

    * Name could be the artist/album of the first entry?  Maybe pop up a box asking what to call it?

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Little Credits or Help screen

* Idea: backspace in search window takes you "up" a detail level if you've done a detail browse. AKA
  "show previous search results".  One approach could be to store the list of tracks returned by
  various searches, up to e.g. 10 ago.

## Things i can't do much about

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.
  https://github.com/librespot-org/librespot/issues/276,
  https://github.com/librespot-org/librespot/discussions/609

* Automatically switch audio output sink when using Sound.prefpane.
  https://github.com/RustAudio/rodio/issues/327

* Make `?` highlight the currently-playing track in the search results, too.
