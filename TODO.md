# TODO list

## Before it's ready for showing people

* Sparkle framework or other auto update


## Other

* page up / down should bring focussed row along for the ride.

* under high CPU load spotiqueue-worker seems to falter.  supposedly a
  release build will help... OK so. A release build drops CPU to about
  10-12% when Spotiqueue is idling.  Still no good.  It looks as if it
  starts as soon as `spotiqueue_initialize_worker` is called, and it
  seems (see Profiler of XCode) to be a thread suggestively called
  com.apple.audio.iothread.client taking that CPU time.  Weirdly
  though, when i wrote a Rust client app with a main.rs that simply
  boots the library with that call, it doesn't _appear_ to use much
  CPU (merely .5% or so).  In `flamegraph` output it does however seem
  that CoreAudio HALB_IOThread is doing most of the time.

  Is it something about going via the static library / C FFI boundary?
  That's something the Rust client app avoids - it's using rlib
  style.  Next test would be to use spotiqueue-worker as a static
  library too.  Then there's also a question of how Swift's threading
  runtime interacts with Rust/Tokio?  No idea.

* Automatically switch audio output sink when using Sound.prefpane

* Copying and pasting of spotify URIs
* Dragging items position in queue
* Dragging items into queue from search

* Media keys, globally

* total remaining queue time

# Ideas

* If doing album-browse, put "album:..." into the search bar?

* Search: if searching for "album:...URI..." plus a term, maybe filter results (locally) on those terms?

* Some sort of local "filter results" function.  Press "/" or something?
  present only items matching (regex) filter in at least one of their fields?


# Lower priority

* Save queue to .. NSUserDefaults? Text file?

* Loved tracks retrieval
* Add/remove star

* All playlists retrieval
* Create playlist.. maybe?

* Search: Does "album:asdf" make sense? Search for "asdf" in album titles?  why not _just_ search for "asdf"?  Maybe park that idea until it turns out i'm often failing to find what i'm after in one go.

* Play/pause button

* Deal with incorrect username/password.

* Show popup or something when successfully received callback from
  spotify for authorisation.  Something to the effect of "you may
  close the browser window"
