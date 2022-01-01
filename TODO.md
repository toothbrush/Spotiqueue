# TODO list

* Figure out how to build for `arm64` & `x86_64`, which means.. figuring that out for `libguile` and
  `spotiqueue_worker`, too. :(

* Ensure that focus is always something sensible (read: search bar) on app startup.  With and
  without displaying login flow. Might be complex:
  http://www.extelligentcocoa.org/the-strange-case-of-initialfirstresponder/

* We really need proper auth-failure handling.  Especially an invalid refresh token just makes the
  app crash 👎

* Add all features to app menus for discoverability.

* When moving tracks in queue consider scrolling such that there's a
  3-4 track "buffer" of not-selected tracks between the selected block
  and the edge of the view.

* Get Xcode to build my dependencies from source so we can once and for all squash the warnings
  about `MACOS_DEPLOYMENT_TARGET`, etc., as well as the unmitigated disaster which is the
  libraries-from-Homebrew hassle.

* Little Credits or Help screen

* Idea: backspace in search window takes you "up" a detail level if you've done a detail browse. AKA
  "show previous search results".  One approach could be to store the list of tracks returned by
  various searches, up to e.g. 10 ago.

## Things i can't do much about

* Leave the app idle for a long time, play a track ->
  spotiqueue_worker session is invalid and client shuts down.
  https://github.com/librespot-org/librespot/issues/276,
  https://github.com/librespot-org/librespot/discussions/609
  Is this fixed in https://github.com/librespot-org/librespot/pull/783?

* Automatically switch audio output sink when using Sound.prefpane.
  https://github.com/RustAudio/rodio/issues/327

* very quick fade in / out when pausing? - maybe shorten the audio buffer in librespot? Turns out
  it's something i can't easily fix, because they also adjust audio volume per buffer chunk, grr.

## Guile bindings ideas

* Allow filtering search results through a hook.  E.g., never show Coldplay in the results.

* Last.fm scrobbling with Guile.

* Get current queue or search results contents as a list.

* Can i remove a layer of boilerplate by using the @c_externdecl or whatever directly in Swift?
