# Instructions for setting up local dev environment

You will need:

* Working Rust tools
* The external libraries we depend on, which are now vendored in here _for reasons_

## TL;DR

```sh
# Get rustup, to install cargo and Rust compiler toolchain:
brew install rustup-init && rustup-init
# or
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Enable cross-compilation of Rust library:
rustup target install x86_64-apple-darwin
rustup target install aarch64-apple-darwin

# Unpack vendored binary libraries:
make -C vendor all
```

Don't forget the `make all` bit in `vendor/`, which sets up our crazy libraries correctly!

## More detail

### Hand-creating `libguile` Universal binary from Homebrew

To build a Universal binary, i need to have ARM64 and Intel versions of all my dependencies. I could
learn how to build `libguile`, `bdw-gc`, etc. but their build instructions are .. non-trivial. So
instead i'm cheating and downloading the Intel and ARM versions from Homebrew (they kindly do the
work of working out how to build for me) and stitching them together myself with `lipo`, the [now
apparently deprecated
tool](https://github.com/rust-lang/cargo/issues/8875#issuecomment-828404158)...  Probably building
things myself would be more ideologically pure, but hey.

At the moment, we depend on the following libraries.  Their names, as reflected in
[Homebrew](https://github.com/Homebrew/homebrew-core/tree/master/Formula):

* guile
* bdw-gc
* gmp
* libunistring

There's a `vendor/` folder in this repo, and it takes care of the dependency stuff for me.  We have
committed known-good versions of the Homebrew libraries for our dependencies in both ARM and Intel
formats.  To be able to use them though, we need to do a tiny bit of massaging:

* Unpack the tarballs
* Use `lipo` to create fat binaries
* Collect some header files into one location where Xcode expects to find them (`vendor/include/`)

Mostly, you should just be able to run `make -C vendor all` in the root of this repo.  However, you
might want to do maintenance.

If you're looking to update the vendored-in library versions:

```shellsession
$ cd vendor/
$ brew fetch --bottle-tag=big_sur guile bdw-gc gmp libunistring
Downloaded to: /Users/paul/Library/Caches/Homebrew/downloads/a297b225b0a05f699f6d9a1c41e33fc810aee6ee12c24cfef4ff14ae3cfdf73a--guile--3.0.7_2.big_sur.bottle.tar.gz
... etc ...
$ brew fetch --bottle-tag=arm64_big_sur guile bdw-gc gmp libunistring
Downloaded to: /Users/paul/Library/Caches/Homebrew/downloads/34a984164cd0c16b3b14639f9d6da15f06b2692e46b53e08c5af6fe929106f00--guile--3.0.7_2.arm64_big_sur.bottle.tar.gz
... etc ...
```

Why `big_sur` and not `catalina`, i hear you ask?  Well, Catalina-SDK builds aren't provided for
ARM64, so i'm picking the oldest version that provides ARM and Intel.  This causes reams of warnings
about libguile having been built for a newer SDK than the one Spotiqueue targets, but i'm counting
on that being fine.  Hope it is.  Presumably libguile doesn't depend on any macOS APIs anyway... 🤔

Make sure they're in the `vendor/` folder, and commit: (maybe don't forget to `git rm` old versions, too).

```shellsession
$ cp ~/Library/Caches/Homebrew/downloads/*guile*.tar.gz .
.. etc ..
$ git add *.tar.gz; git commit
```

### Guile

The project expects to link against Guile's `libguile`.  That was rather a hassle to get right, but
it turns out that we can, after all, link statically against Homebrew's `guile` package.  _(Voice
from the future)_ It wasn't that easy, of course.  We sort-of still can do that, except as stated
above we need to create a universal/fat binary with ARM64 and Intel architectures, which no single
Homebrew package provides (because why would they).

The Xcode project expects to find libraries to link against in `vendor/lib/`, so that's where we
collect the fat binaries.  It looks for headers in `vendor/include/`, but only needs headers for
libguile and gmp.  Surprised it doesn't need the others, actually.  Ah, probably because they're
only used when building libguile and gmp?  Dunno.

If any of this changes, you might have to go fishing around in `OTHER_LDFLAGS` of the Xcode project.
Otherwise it should all be fine though.  Note that the order of elements in `LDFLAGS` is
significant.  You may encounter errors such as "xyz symbol already defined" if you get it wrong.

It's also imperative to have Xcode set to allow ("Entitlements") execution of JIT-compiled code, and
allow unsigned executable memory.  Otherwise, our app will fail on startup with a `jit.c` exception
from inside libguile somewhere.  Fair enough!

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.cs.allow-jit</key>
	<true/>
	<key>com.apple.security.cs.allow-unsigned-executable-memory</key>
	<true/>
</dict>
</plist>
```

Finally, versions.  This was quite a hassle to get right, and involved [talking to the friendly
Homebrew maintainers](https://github.com/Homebrew/discussions/discussions/2114).  I distribute the
app with `MACOSX_DEPLOYMENT_TARGET == 10.15`, because that's the minimum i can get away with for now
while using [SpotifyAPI](https://github.com/Peter-Schorn/SpotifyAPI).  However, since i don't
actually run 10.15, but 11.x, Homebrew will actually pull in a version built for your exact platform
by default.  A workaround that seems acceptable for now is to explicitly tell Homebrew to download
and install libraries built on 10.15 (codename `catalina`), and link against those:

```shellsession
$ brew fetch --bottle-tag=catalina guile
Downloaded to: /Users/me/Library/Caches/Homebrew/downloads/927d2790fab48c9bd4dfbe020b30e94987df1e8f54ab60ac55bf84a012da66d4--guile--3.0.7.catalina.bottle.tar.gz
SHA256: ee1867daea429b0e7867a30890e07f3c7e4a69d6d483c728c912aea34aa4f83d
$ brew reinstall --force /Users/me/Library/Caches/Homebrew/downloads/927d2790fab48c9bd4dfbe020b30e94987df1e8f54ab60ac55bf84a012da66d4--guile--3.0.7.catalina.bottle.tar.gz
```

I'm leaving the previous paragraph as historical context, because we've already employed this trick
above.

### Rust

You'll need to have [Rust tools installed](https://www.rust-lang.org/tools/install), from there the
Xcode project should simply be able to be built & run.  The `spotiqueue_worker` library is wrapped
in a Xcode dependency project, see [the `cargo-xcode`
documentation](https://lib.rs/crates/cargo-xcode).  That's a nifty project which auto-generates an
Xcode project for inclusion in a workspace.

It has, however, since been manually modified for cross-compilation -- have a look at the various
**Build Phases** in that Xcode project.  For those steps to succeed, you'll need the Rust
cross-compilation toolchain, too -- see the instructions at the top of this document.
