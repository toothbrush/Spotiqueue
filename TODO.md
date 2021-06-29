# TODO list

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

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Little Credits or Help screen

* Why are the table column headers sometimes differently-coloured???

* I want a key shortcut to search for the currently playing song or
  album. Consider adding a menu item.

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.

* Blake's idea: show most recent search in label next to search
  field.

* Might also be good to keep track of what "previous" means.  List of
  search and browse actions you can replay?

* Idea: backspace in search window takes you "up" a detail level if
  you've done a detail browse.
