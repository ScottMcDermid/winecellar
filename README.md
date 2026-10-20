# game-framework

Makefile-driven tooling for running Windows games on Linux, each in its own
isolated wine prefix.

## Requirements

- `wine` on your `PATH`
- GNU Make, bash

## Layout

Each game gets its own directory, nested under `games/` (ignored by git,
since prefixes are large and machine-specific):

```
games/<game_name>/
├── prefix/        # WINEPREFIX for this game only
└── launch.txt     # absolute path of the exe `make run` should launch
```

## Usage

```sh
# 1. Create an isolated wine prefix for a game
make init <game_name>

# 2. Run an installer (or a portable exe) inside that prefix.
#    The resulting new executable is auto-detected and remembered.
make install <game_name> <path-to-exe>

# 3. Launch the game later
make run <game_name>

# See what's been set up
make list
```

### Example

```sh
make init stardew
make install stardew ~/Downloads/StardewValleySetup.exe
make run stardew
```

If an installer drops more than one new `.exe` into the prefix, `install`
lists the candidates and asks you to pick one explicitly:

```sh
make install stardew ~/Downloads/StardewValleySetup.exe 'games/stardew/prefix/drive_c/Stardew Valley/Stardew Valley.exe'
```

If `install` detects no new executables at all (common for portable, no-installer
games), it assumes the exe you passed in *is* the game and records that directly.

### Notes

- `WINEARCH` defaults to `win64` for `make init`; override with
  `WINEARCH=win32 make init <game_name>`.
- `make run` always launches wine from the recorded executable's own
  directory, so games that expect relative asset paths work correctly.
- To change what `make run` launches, edit `games/<game_name>/launch.txt`
  directly, or re-run `make install` with an explicit launch override.
