# DockSearch Reborn

Adds a browser search bar to the iOS dock: raise the dock, type, and it opens
your default browser (or a chosen search engine) with the query. A
rootless/roothide port of [Ginsu's DockSearch](https://github.com/ginsudev/DockSearch)
(GPLv3), which never got rootless support.

## What changed from the original

- **Rootless and roothide support** | the actual point of this fork. The
  original only ever worked on rootful jailbreaks.
- **Adjustable background opacity**, instead of just an on/off toggle | dial
  the search bar's blurred background to exactly how transparent you want it.
- **Vertical offset**, to nudge the bar's position up or down.
- A couple of features tied to a separate, unrelated tweak (AndroBar) were
  dropped rather than carried over half-working.

Everything else,  the search bar itself, the search engine picker, works
the same as the original.

## Tested Environment

Targets firmware >= 14.0, same lower bound as the original. Built via
GitHub Actions on a macOS runner with a real Xcode toolchain.

## Settings

Open **Settings → DockSearch Reborn**.

- **Enabled**: on/off. Needs a respring to take effect.
- **Search engine**: Google, Baidu, Bing, Yahoo, DuckDuckGo, or YouTube.
- **Background opacity**: slider, fully transparent to fully opaque.
- **Search bar below icons**: move the bar under the dock instead of above
  it.
- **Vertical offset**: nudge the bar up or down from its chosen position.

No respring needed to change options (only activating/deactivating the
tweak requires a respring)

## Building from source

Requires [Theos](https://theos.dev) plus a real Xcode toolchain.

```sh
make package THEOS_PACKAGE_SCHEME=rootless
```

## Credits

- Original DockSearch: [Ginsu](https://github.com/ginsudev) (GPLv3).
- This rootless/roothide fork: brkr1.

## License

GPLv3, inherited from the original (see `LICENSE`).

## Support

If you like my tweaks, consider buying me a coffee:

<a href="https://buymeacoffee.com/brkr1" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="41" width="174"></a>
