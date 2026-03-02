# Xcode Language Plugins

This repo contains legacy Xcode language plug-ins for:

- Nim in `plugins/nim`: 
    ```bash
    sudo ./plugins/nim/setup.sh
    ```
- Odin in `plugins/odin`
    ```bash
    sudo ./plugins/odin/setup.sh
    ```
Restart Xcode after installing either plugin. See [examples](#examples) for example projects.

Based on [rust-xcode-plugin](https://github.com/BrainiumLLC/rust-xcode-plugin/).

## Plugin Details

Each language plugin is composed of:
- the `.ideplugin` bundle copied into `~/Library/Developer/Xcode/Plug-ins/`
- the `.xcspec` copied into the selected Xcode app's `LanguageSpecifications`
- the `.xclangspec` copied into the selected Xcode app's `LanguageSpecifications`
- the `Xcode.SourceCodeLanguage.*.plist` copied into the selected Xcode app's `LanguageMetadata`

## Examples

### Odin

Update `examples/odin/env.sh` to point to the path where the Odin complier exists.

Odin example projects live in:

- `examples/odin/basic` for a command line target
- `examples/odin/macos-app` for a native macOS app that renders with Metal

Each sample project builds `src/` with `odin build` and switches between `-debug` and `-o:speed` based on the active Xcode configuration.

### Nim

Update `examples/nim/env.sh` to point to the path where the Nim complier exists.

- `examples/nim/basic`: a basic CLI program
