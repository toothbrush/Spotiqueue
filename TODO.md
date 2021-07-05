# TODO list

## Other

* Automatically switch audio output sink when using Sound.prefpane - https://github.com/RustAudio/rodio/issues/327

* Media keys, globally

# Lower priority

* Loved tracks retrieval
* Add/remove star

* Create playlist.. maybe? By default suggest name "Artist - Album"
  based on first selected item?  Or based on current queue?

* Deal with incorrect username/password gracefully.

* better logging framework, show messages in Console.app.

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Little Credits or Help screen

* I want a key shortcut to search for the currently playing song or
  album. Consider adding a menu item.

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.
  https://github.com/librespot-org/librespot/issues/276,
  https://github.com/librespot-org/librespot/discussions/609

* Idea: backspace in search window takes you "up" a detail level if
  you've done a detail browse.

* Search label should auto size to fill space until search box.
