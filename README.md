# MarkD

Markdown editor + preview and an RTF/HTML to Markdown converter.

## Prerequisites

- Flutter SDK installed and on PATH
- Desktop tooling for your target OS
  - Windows: Visual Studio 2022 with "Desktop development with C++"
  - macOS: Xcode + Command Line Tools
  - Linux: build essentials (clang, cmake, ninja, pkg-config, libgtk-3-dev)

## Run locally

```bash
flutter pub get
flutter run -d windows
```

## Build / deploy

### Windows

```bash
flutter build windows --release
```

Output:
- `build/windows/x64/runner/Release/MarkD.exe`

Distribute the entire `Release` folder or package it with an installer.

### macOS

```bash
flutter build macos --release
```

Output:
- `build/macos/Build/Products/Release/MarkD.app`

To distribute outside your machine, codesign and notarize the app per Apple
requirements.

### Linux

```bash
flutter build linux --release
```

Output:
- `build/linux/x64/release/bundle/markd`

Distribute the full `bundle` directory with required shared libraries.

### Web (optional)

```bash
flutter build web --release
```

Output:
- `build/web/`

Host the `build/web` folder on any static hosting provider.

## Enable desktop targets

If a target is not enabled, run:

```bash
flutter config --enable-windows-desktop
flutter config --enable-macos-desktop
flutter config --enable-linux-desktop
```
