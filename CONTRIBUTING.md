# Sharing a widget

Open a pull request that adds one folder to `widgets/`. When it's merged, the
widget gets a page at `chopstick.sh/widgets/<id>` that credits you, and anyone
can install it from there.

## The folder

```
widgets/
  my-widget/
    widget.json
    icon.png           # optional
    fetch.sh           # whatever it runs
    screenshots/
      01-glance.webp
      02-glance-folded.webp
```

Export the widget from Chopstick (Export… on its page in Settings) and unzip it
here, so the folder is what Chopstick actually runs. Then add to its
`widget.json`, after `description`:

```json
"author": "your-github-handle",
"version": "1.0.0",
```

- **`id`** is the folder's name and the widget's URL on the site, so it can't
  change later. Lowercase with dashes, and not already taken here or by a
  widget that comes with Chopstick.
- **`author`** is your GitHub handle. The site shows your GitHub name and
  picture, and links to your profile. Anyone whose commits change a widget
  later is listed as a contributor on its page.
- **`version`** follows [semver](https://semver.org). Bump it whenever you
  change the widget.

## Screenshots

Put at least one picture of the widget in use in `screenshots/`. The site shows
them in file name order. They don't ship in the widget's download.

Ask Chopstick's agent to `preview_widget` each state with `transparent: true`
(and once more with `folded: true`). That captures only the island on
transparent pixels, and the site puts it on a backdrop in the icon's colors.
WebP or PNG.

## What gets merged

Every script in a widget runs on someone's Mac, so each one is read before it's
merged. To get through review:

- Keep scripts readable: shell, Python, or JavaScript for Automation. No
  compiled binaries, no minified or obfuscated code, nothing downloaded and run
  at runtime.
- Only reach the network for what the widget is about, and say which services
  it talks to in the PR.
- Write only to `CHOPSTICK_STORAGE`, never into the widget's own folder or
  elsewhere on disk.
- Make the `description` one plain sentence about what the widget shows or does.
- Make `preview` show something real.

By opening a pull request you agree to license your widget under this repo's
[MIT license](LICENSE).
