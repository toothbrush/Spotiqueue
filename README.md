# Spotiqueue

A terribly simple macOS app for keyboard-based queue-oriented Spotify use.  Many years ago i built
another version which relied on a now-deprecated library (Spotify doesn't publish `libspotify` any
more, which is a shame).  It is [archived for
posterity](https://github.com/toothbrush/spotiqueue-old); this one does pretty much exactly the same
as the old one did, although i'd like to think it's a bit more refined.

Beware of rough edges. Scratches my itch, no other guarantees granted.

![Obligatory screenshot to give an idea what the app does.](img/screenshot.png)

## Keyboard shortcuts

* Use arrows or `j`, `k` to navigate around lists (optionally using shift to select stuff).
* Left and right arrows or `h`, `l` switch focus between queue and search results.
* Supports some Vim keys (e.g., `j`,`k`,`g`,`G`).
* Holding the command-key and using the navigation keys moves selected tracks up or down in the queue.
* Tab cycles through search (`⌘F` or `⌘L`), search results, and queue.
* Space bar pauses and unpauses (unless search field has focus).
* Pressing ⏎ (Return) on a single item plays it immediately.
* Pressing ⏎ with multiple songs selected adds them to the top of the queue and starts playing them.
* `⌘←` enqueues, `⌘⇧←` enqueues at the top of the queue.
* `⌘N` skips to the next track. Also useful for starting playback.

## Download

If you don't like hassling about with XCode (quite rightly so), you can find compiled versions
[here](https://github.com/toothbrush/Spotiqueue/releases).  Unfortunately for now you need at least
macOS 10.15, because the app makes heavy use of the Combine framework.  It should be able to
auto-update once installed.

## Development

You'll need to have [Rust tools installed](https://www.rust-lang.org/tools/install), from there the
Xcode project should simply be able to be built & run.  The `spotiqueue_worker` library is wrapped
in a Xcode dependency project, see [the `cargo-xcode`
documentation](https://lib.rs/crates/cargo-xcode).
