# Instructions for setting up local dev environment

You will need:

* Working Rust tools
* Guile installed from Homebrew (_insert many caveats_)

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
go fishing around in `OTHER_LDFLAGS` of the Xcode project (because the path looks like
`/usr/local/Cellar/guile/<version>/...`).  Otherwise it should all be fine though.  Note that the
order of elements in `LDFLAGS` is significant.  You may encounter errors such as "xyz symbol already
defined" if you get it wrong.

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

You will want to do that for all the dependencies statically linked.  Currently, the list of
Homebrew package names to do that dance for is:

* guile
* bdw-gc
* gmp
* libunistring

### Rust

You'll need to have [Rust tools installed](https://www.rust-lang.org/tools/install), from there the
Xcode project should simply be able to be built & run.  The `spotiqueue_worker` library is wrapped
in a Xcode dependency project, see [the `cargo-xcode`
documentation](https://lib.rs/crates/cargo-xcode).  That's a nifty project which auto-generates an
Xcode project for inclusion in a workspace.
