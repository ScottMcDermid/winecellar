# winecellar

Makefile-driven tooling for running Windows games on Linux, each in its own
isolated wine prefix.

## Requirements

- `wine` on your `PATH`
- `jq` on your `PATH` (used to read/write each game's `config.json`)
- `7z` on your `PATH` (used by `make install` to extract `.iso` installers;
  optional if you only ever install from `.exe`)
- `gamescope` on your `PATH` (optional, but `make run` uses it by default to
  launch games in their own nested session)
- GNU Make, bash

## Layout

Each game gets its own directory, nested under `games/` (ignored by git,
since prefixes are large and machine-specific):

```
games/<game_name>/
├── prefix/            # WINEPREFIX for this game only
├── config.json        # generated, per-game options (e.g. launch exe, gamescope args)
└── logs/               # gamescope/wine output from the last `run` and each `tool`
```

`config.json` is a small, flat JSON object. `make install` and `make config`
write to it; `make run` reads from it. You generally don't need to edit it by
hand, but it's just JSON if you want to.

`make run`/`make tool` keep the terminal to their own succinct status lines;
gamescope and wine's own (very chatty) output is redirected to
`games/<game_name>/logs/run.log` (or `tool-<name>.log` for `make tool`),
overwritten each time you launch. Worth a look if something misbehaves:

```sh
make logs <game_name>              # print the main run log
make logs <game_name> tool-wrye-bash   # print a specific tool's log
FOLLOW=1 make logs <game_name>     # tail -f instead of printing once
```

## Usage

```sh
# 1. Create an isolated wine prefix for a game
make init <game_name>

# 2. Run an installer (or a portable exe) inside that prefix.
#    The resulting new executable is auto-detected and remembered.
make install <game_name> <path-to-exe>

# 3. Launch the game later (`make launch` is an alias for `make run`)
make run <game_name>

# 3b. Or launch a different executable inside that same prefix
#     (doesn't change the recorded launch target)
make run <game_name> <path-to-exe>

# 3c. Record and launch an auxiliary tool in the same prefix, e.g. a mod
#     manager like Wrye Bash (gamescope is off by default for these)
make tool <game_name> wrye-bash <path-to-exe>
make tool <game_name> wrye-bash

# See what's been set up
make list

# Stuck session (gamescope hung after quitting)? Force-kill it:
make kill <game_name>
```

### Interactive menu (`make menu`)

Prefer picking from a list over remembering `<game_name>`s and flags?
`make menu` is a numbered, interactive front end over everything above - browse
existing games, launch them, install/reinstall, record and launch tools, view
or edit config, open the registry editor, view logs, kill a stuck session, or
set up a brand-new game, all from one menu:

```sh
make menu
```

It just shells out to the same scripts behind `make run`/`make install`/etc.,
so behavior (logs, gamescope, confirmations before deleting a game, ...) is
identical either way - this is purely a friendlier way to drive them.

### Example

```sh
make init stardew
make install stardew ~/Downloads/StardewValleySetup.exe
make run stardew
```

If an installer drops more than one new `.exe` into the prefix, `install`
lists the candidates as a numbered menu and prompts you to pick one:

```
Multiple new executables appeared for 'stardew':

  1) games/stardew/prefix/drive_c/Stardew Valley/Stardew Valley.exe
  2) games/stardew/prefix/drive_c/Stardew Valley/unins000.exe

Select the one to launch [1-2]:
```

If `install` isn't running in an interactive terminal (no TTY attached), it
falls back to printing the candidates and asking you to re-run it naming the
one to launch explicitly. The positional form only reconstructs two logical
args (`game_name`, `exe_path`), so a launch override needs the variable form:

```sh
make install GAME=stardew EXE=~/Downloads/StardewValleySetup.exe LAUNCH='games/stardew/prefix/drive_c/Stardew Valley/Stardew Valley.exe'
```

If `install` detects no new executables at all (common for portable, no-installer
games), it assumes the exe you passed in *is* the game and records that directly.

### Installing from an `.iso`

`make install` also accepts a disc image directly - handy for GOG/retail
installers distributed as `.iso`:

```sh
make install skyrim ~/Downloads/Skyrim.iso
```

Passing a path ending in `.iso` extracts it to a temporary directory (via
`7z`, so no mounting or root access is needed), looks for the installer
inside (preferring `setup.exe`, then `autorun.exe`, skipping redistributable
bundles like DirectX/VC++ installers), and runs that inside the prefix. Pick
the one to run yourself if several plausible candidates turn up:

```
Multiple possible installers found inside /home/me/Downloads/Skyrim.iso:

  1) Game/setup.exe
  2) Game/Data/setup.exe

Select the one to run [1-2]:
```

Everything else - new-exe detection, the `launch` override argument, etc. -
works the same as installing from a plain `.exe`. The extracted copy is
deleted once `install` finishes; only what the installer wrote into
`games/<game_name>/prefix/` sticks around. Requires `7z` (p7zip) on your
`PATH`.

Some older discs (CD-ROM XA/Mode 2 titles, hybrid Mac/PC discs burned with
tools like Toast, etc.) are dumped as a raw image with 2352-byte sectors
instead of the plain 2048-byte layout most ISO tools expect, so they fail
plain extraction even though the file is a perfectly valid `.iso`. `install`
detects that case automatically and converts it before extracting - this
step needs `python3` on your `PATH` (only when this fallback actually
triggers; a standard `.iso` never needs it).

### Mod managers & other auxiliary tools (`make tool`)

Some tools need to run *inside* the same wine prefix as the game - a mod
manager like [Wrye Bash](https://www.nexusmods.com/oblivion/mods/22368) is
the canonical example: it reads the game's registry keys, `Data` folder, and
plugin list, so it has to share the prefix rather than live in its own.

Unlike `make install`, `make tool` never touches the `launch` config key, so
it can't accidentally make `make run <game_name>` launch the mod manager
instead of the game. It also disables gamescope by default, since these are
normally windowed GUI apps rather than full-screen games.

```sh
# Record a tool's path (run its installer with `make run` first if it has
# one, or just point at wherever its exe ends up):
make run oblivion ~/Downloads/Wrye_Bash_308_Installer.exe
make tool oblivion wrye-bash 'games/oblivion/prefix/drive_c/GOG Games/Oblivion GOTY Deluxe/Mopy/Wrye Bash.exe'

# Launch it later, by name, any time:
make tool oblivion wrye-bash

# List every tool recorded for a game:
make tool oblivion

# Force gamescope on for a particular tool anyway:
NO_GAMESCOPE=0 make tool oblivion wrye-bash
```

Paths are recorded per game under `tool_<name>` keys in `config.json` (see
below), so re-running `make tool <game_name> <name> <path-to-exe>` with a new
path updates it in place.

### Configuring a game (`config.json`)

Every option `make run` looks at is read from `games/<game_name>/config.json`,
a small generated JSON file. View or change it with `make config`:

```sh
# print the whole config for a game
make config stardew

# print a single value
make config stardew launch

# set a value
make config stardew gamescope_args '-W 1920 -H 1080 -f'
```

Supported keys today:

| key              | set by           | meaning                                        |
| ---------------- | ---------------- | ----------------------------------------------- |
| `launch`         | `make install`   | absolute path of the exe `make run` launches    |
| `gamescope_args` | `make config`    | default gamescope flags for this game           |
| `tool_<name>`    | `make tool`      | absolute path of the auxiliary exe named `<name>` |

More options can be added the same way as the framework grows; `config.sh`
and the `config_get`/`config_set` helpers in `scripts/common.sh` don't care
which key you use.

### gamescope

`make run <game_name>` launches the recorded game inside [gamescope](https://github.com/ValveSoftware/gamescope)
by default, giving it its own nested session (handy for resolution/scaling,
borderless/fullscreen, and keeping a misbehaving game from wrecking your
desktop). `make run <game_name> <path-to-exe>` (launching a one-off exe
instead of the recorded game) flips the default to *off*, since that's
usually a tool or installer rather than the game itself; force it on with
`NO_GAMESCOPE=0`. Configure it per run or per game:

```sh
# one-off override
GAMESCOPE_ARGS='-W 1920 -H 1080 -f' make run stardew

# persistent default for this game
make config stardew gamescope_args '-W 1920 -H 1080 -f'
make run stardew

# skip gamescope entirely for this run
NO_GAMESCOPE=1 make run stardew
```

`GAMESCOPE_ARGS` always wins over the `gamescope_args` config value when both
are set. If `gamescope` isn't installed, `make run` warns and falls back to
launching wine directly.

`make tool` uses the same `gamescope_args`/`GAMESCOPE_ARGS` config, but flips
the default to *off* (since tools are usually windowed GUI apps, not games).
Force it on for one run with `NO_GAMESCOPE=0 make tool <game_name> <name>`.

`make run` always adds `--force-grab-cursor` on top of whatever's in
`GAMESCOPE_ARGS`/`gamescope_args`. Without it, gamescope only grabs the mouse
in relative mode when it guesses the game wants that (based on cursor
visibility), which guesses wrong for a lot of wine games and lets the cursor
escape the window or breaks mouse-look. Disable it with:

```sh
GAMESCOPE_FORCE_GRAB_CURSOR=0 make run stardew
```

#### Stuck sessions

gamescope has a long-standing upstream bug where it sometimes hangs onto the
terminal after the wrapped game quits normally instead of exiting on its own
([ValveSoftware/gamescope#777](https://github.com/ValveSoftware/gamescope/issues/777)).
`make run`/`make tool` watch for this automatically: once the game's own
process has exited, gamescope gets a short grace period (default 10s) to
notice and exit on its own; if it's still running after that, the whole
session (gamescope, wine, wineserver) is force-killed so the terminal is
released without you having to do anything. `Ctrl+C` also force-kills the
session immediately, bypassing gamescope's own shutdown path entirely in
case that's what's stuck.

```sh
# disable the automatic watcher (back to having to Ctrl+C/make kill by hand)
GAMESCOPE_AUTO_KILL=0 make run stardew

# change the grace period (seconds) before an auto-kill kicks in
GAMESCOPE_AUTO_KILL_GRACE=20 make run stardew
```

A separate watcher handles the other common way a session gets stuck: wine
itself deadlocking internally rather than gamescope failing to notice a
clean exit - the most common case being a DirectShow/`quartz` filter-graph
hang some Bethesda-engine games hit tearing down video playback on exit
(`err:quartz:BaseMemAllocator_Decommit Waiting` repeating in
`make logs <game_name>`). Since wine's own process never exits at all in
that case, there's nothing for the watcher above to notice - instead, once
that specific error shows up in the log, wine gets a grace period (default
15s) to log anything further (or exit) before being treated as stuck:

```sh
# disable just this watcher (the gamescope-exit one above still runs)
WINE_HANG_AUTO_KILL=0 make run stardew

# change its grace period (seconds)
WINE_HANG_GRACE=30 make run stardew
```

If a session somehow gets away from all of that (e.g. one started before
this existed, or some other unrecognized hang), force-kill everything tied
to a game's wine prefix by hand from another terminal:

```sh
make kill <game_name>
```

### Tab completion

`make completion` (bash) / `make completion-zsh` (zsh) print a tab-completion
script for this project's subcommands (`init`, `install`, `run`, `tool`,
`config`, ...), `<game_name>` (from `games/`), recorded tool names, config
keys, and log names. Add one to your shell once:

```sh
# bash (~/.bashrc)
echo 'eval "$(make -C /path/to/winecellar completion)"' >> ~/.bashrc

# zsh (~/.zshrc, after compinit)
echo 'eval "$(make -C /path/to/winecellar completion-zsh)"' >> ~/.zshrc
```

(or `source /path/to/winecellar/scripts/completion.bash`/`completion.zsh`
directly). Either only takes over `make` completion while you're inside a
winecellar checkout, so they're safe to add globally - everywhere else,
`make` completion behaves as it did before (falling back to bash-completion's
`_make`/zsh's `_make`, if installed).

### Paths with spaces

`make run`, `make launch`, `make tool`, and `make install` each reconstruct
their own exe-path argument from everything after the fixed, non-spaced
words that come before it, so passing a spaced path positionally works fine
for those:

```sh
make run oblivion '/home/me/My Downloads/tool.exe'
make install oblivion '/home/me/My Downloads/setup.exe'
make tool oblivion wrye-bash '/home/me/My Downloads/Wrye Bash.exe'
```

That reconstruction only covers one trailing path, though - `make config`
(`key`/`value`) and `install`'s optional launch-override 3rd arg can't tell
where one argument ends and the next begins once spaces are involved, so
those need the variable form instead, which keeps each value intact
regardless of position:

```sh
make install GAME=oblivion EXE='/home/me/My Downloads/setup.exe' LAUNCH='/home/me/My Downloads/Game.exe'
make init GAME=oblivion
make run GAME=oblivion
make run GAME=oblivion EXE='/home/me/My Downloads/tool.exe'
make tool GAME=oblivion TOOL=wrye-bash EXE='/home/me/My Downloads/Wrye Bash.exe'
make config GAME=oblivion KEY=gamescope_args VALUE='-W 1920 -H 1080 -f'
```

Parentheses, `&`, and other shell-special characters in a path are fine
either way - they're automatically quoted for you.

### Notes

- `WINEARCH` defaults to `win64` for `make init`; override with
  `WINEARCH=win32 make init <game_name>`.
- `make run` always launches wine from the recorded executable's own
  directory, so games that expect relative asset paths work correctly.
- To change what `make run` launches, run `make config <game_name> launch
  <path-to-exe>`, or re-run `make install` with an explicit launch override.
- Need a one-off, e.g. a mod tool or benchmark that lives in the same
  prefix? Pass its path as a second argument: `make run <game_name>
  <path-to-exe>`. This launches from that executable's own directory and
  respects the same `gamescope_args`/`GAMESCOPE_ARGS` config, but doesn't
  touch the recorded `launch` config value. Gamescope defaults to *off* for
  this one-off form; force it on with `NO_GAMESCOPE=0`.
- Need the same auxiliary exe again later (a mod manager, a benchmark you
  run repeatedly, etc.)? Give it a name with `make tool <game_name> <name>
  <path-to-exe>` instead, so you can launch it again with just `make tool
  <game_name> <name>`. Gamescope is off by default for tools; `make run`
  is still the right choice for genuine one-offs.
