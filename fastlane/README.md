fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload App Store metadata (37 storefronts) and screenshots. Regenerate first with Tools/make_store_screenshots.sh and Tools/asc_listing.py.

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Archive a Release build with automatic signing and upload it to TestFlight.

### ios release

```sh
[bundle exec] fastlane ios release
```

Metadata, screenshots and a TestFlight build in one go.

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
