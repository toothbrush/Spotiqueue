# TODO list

* page up / down should bring focussed row along for the ride.

* under high CPU load spotiqueue-worker seems to falter.
  supposedly a release build will help...

* Automatically switch audio output sink when using Sound.prefpane

* Copying and pasting of spotify URIs
* Dragging items position in queue
* Dragging items into queue from search

* Media keys, globally

# Ideas

* If doing album-browse, put "album:..." into the search bar?

* Search: if searching for "album:...URI..." plus a term, maybe filter results (locally) on those terms?

* Some sort of local "filter results" function.  Press "/" or something?


# Lower priority

* ...constraints? SwiftUI? ...?
* Better column widths in TableView 🙁

* Nicer login and auth flow.  Maybe use OAUTH for spotiqueue-worker, too.
* Save queue to .. NSUserDefaults? Text file?

* clean debug logs to be a bit more readable 😬

* Loved tracks retrieval
* Add/remove star

* All playlists retrieval
* Create playlist.. maybe?

* Figure out how to conditionally include release/debug version of spotiqueue-worker.


* Search: Does "album:asdf" make sense? Search for "asdf" in album titles?  why not _just_ search for "asdf"?  Maybe park that idea until it turns out i'm often failing to find what i'm after in one go.
