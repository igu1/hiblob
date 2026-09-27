# Hiblob Studio example

<p align="center">
  <img
    src="../hiblob_studio.png"
    width="360"
    alt="Hiblob Studio showing the animated preview, appearance controls, and hover-animated gallery"
  >
</p>

An interactive studio for the local `hiblob` package. Enter any name, pick an
expression (the `thinking` seesaw and `mad` tremor held loops animate on
their own), pin a silhouette, force accessories on or off, and tune the hue,
tone, backdrop, and mouth. **Copy SVG** puts the resolved figure on the
clipboard as a standalone SVG document. The hover-animated gallery at the
bottom shows ambient motion idling out row by row.

From the repository root:

```sh
cd example
flutter pub get
flutter run -d chrome
```

List available devices when Chrome is not the desired target:

```sh
flutter devices
flutter run -d <device-id>
```

The smoketest does not require a window:

```sh
flutter test
```
