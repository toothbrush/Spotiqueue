# Instructions for setting up local dev environment

You will need:

* Working Rust tools
* Guile installed from Homebrew

## TL;DR

```sh
brew install guile
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## More detail

### Guile

The project expects to link against Guile's `libguile`.  That was rather a hassle to get right, but
it turns out that we can, after all, link statically against Homebrew's `guile` package.

It's a bit brittle in that if the version of the installed Guile package changes, you will have to
go fishing around in OTHER_LDFLAGS of the Xcode project.  Otherwise it should all be fine though.
Note that the order of elements in LDFLAGS is significant.

It's also imperative to have Xcode set to allow ("Entitlements") execution of JIT-compiled code, and
allow unsigned executable memory.  Otherwise, our app will fail on startup with a jit.c exception
from inside libguile somewhere.  Fair enough!

### Rust

You'll need to have [Rust tools installed](https://www.rust-lang.org/tools/install), from there the
Xcode project should simply be able to be built & run.  The `spotiqueue_worker` library is wrapped
in a Xcode dependency project, see [the `cargo-xcode`
documentation](https://lib.rs/crates/cargo-xcode).  That's a nifty project which auto-generates an
Xcode project for inclusion in a workspace.
