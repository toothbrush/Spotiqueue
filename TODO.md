# TODO list

* checkbox or something, indicating whether to auto-advance.

* Add all features to app menus for discoverability.

* Media keys, globally - meh use Hammerspoon

* Allow filtering search results through a hook.  E.g., never listen to Coldplay.

* Create playlist:

    * Initially simply create from queue contents, but it'd be nice to have a way (from Guile) to
      create a playlist and add particular songs to it.

    * Name could be the artist/album of the first entry?  Maybe pop up a box asking what to call it?

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Little Credits or Help screen

* Documentation for Guile interface.

* Bug: tracks with UTF-8 in titles get persisted to disk with ??

* Bug: cannot use UTF-8 directly in source.

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
