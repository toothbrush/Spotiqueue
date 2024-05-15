# How to cut a release

I'm a forgetful guy.  Let's see if i can work it out.

1. Get everything building and working obviously.  At this point you'll want to prepare a nice
   branch for merging to `main`.  Don't forget to commit `Spotiqueue.xcodeproj/project.pbxproj`
   which will have an updated `CURRENT_PROJECT_VERSION` which is actually the _build_ number, since
   presumably you've tried it a few times.

1. Update the "marketing version" in the `xcodeproj` file.  Probably it should live in `Info.plist`
   but whatever.

1. By now you should probably be running on `main` with a nice commit history??

1. Run `make build` (this is the default target), it will try to do all the steps.

1. You'll see a Zip file in `updates/Spotiqueue-v*.zip` and an update to `appcast.xml`.  Create a
   release on Github with a tag `vX.Y.Z` pointing at `main` somewhere, and upload the Zip file.
   Ensure `appcast.xml` is appropriately updated too (beware the download URL! and add a DESCRIPTION!).
