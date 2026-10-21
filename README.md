# game-framework

Makefile-driven tooling for running Windows games on Linux, each in its own
isolated wine prefix.

## Requirements

- `wine` on your `PATH`
- `gamescope` on your `PATH` (optional, but `make run` uses it by default to
  launch games in their own nested session)
- GNU Make, bash

## Layout

Each game gets its own directory, nested under `games/` (ignored by git,
since prefixes are large and machine-specific):

```
games/<game_name>/
├── prefix/            # WINEPREFIX for this game only
├── launch.txt         # absolute path of the exe `make run` should launch
└── gamescope.conf     # optional, default gamescope flags for this game
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

### gamescope

`make run` launches the game inside [gamescope](https://github.com/ValveSoftware/gamescope)
by default, giving it its own nested session (handy for resolution/scaling,
borderless/fullscreen, and keeping a misbehaving game from wrecking your
desktop). Configure it per run or per game:

```sh
# one-off override
GAMESCOPE_ARGS='-W 1920 -H 1080 -f' make run stardew

# persistent default for this game
echo '-W 1920 -H 1080 -f' > games/stardew/gamescope.conf
make run stardew

# skip gamescope entirely for this run
NO_GAMESCOPE=1 make run stardew
```

`GAMESCOPE_ARGS` always wins over `gamescope.conf` when both are set. If
`gamescope` isn't installed, `make run` warns and falls back to launching
wine directly.

### Paths with spaces

Positional arguments are split on whitespace by Make itself, so a path like
`/home/me/My Downloads/setup.exe` can't be passed positionally. Use the
variable form instead, which keeps the value intact:

```sh
make install GAME=oblivion EXE='/home/me/My Downloads/setup.exe'
make init GAME=oblivion
make run GAME=oblivion
```

Parentheses, `&`, and other shell-special characters in a path are fine
either way — they're automatically quoted for you.

### Notes

- `WINEARCH` defaults to `win64` for `make init`; override with
  `WINEARCH=win32 make init <game_name>`.
- `make run` always launches wine from the recorded executable's own
  directory, so games that expect relative asset paths work correctly.
- To change what `make run` launches, edit `games/<game_name>/launch.txt`
  directly, or re-run `make install` with an explicit launch override.
