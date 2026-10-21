SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help init install run config list clean

space := $(empty) $(empty)

# Allow positional args after the subcommand, e.g.:
#   make init mygame
#   make install mygame setup.exe
#   make run mygame
GOAL := $(firstword $(MAKECMDGOALS))
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
# Single-quote each arg so filenames with (), $, etc. survive being
# re-inserted into the recipe's shell command line.
QARGS = $(foreach a,$(ARGS),'$(subst ','\'',$(a))')
# Positional goals are split on whitespace by Make itself, so paths with
# spaces can't survive that route in general. GAME=/EXE=/LAUNCH= are regular
# Make variables instead and keep spaces intact, e.g.:
#   make install GAME=oblivion EXE='/path/with spaces/setup.exe'
qv = '$(subst ','\'',$(1))'

# `run` only ever takes two logical positional args (game_name, exe), so
# unlike install/config it can safely treat everything after the first word
# as a single reconstructed exe path, spaces and all. Make still parses each
# whitespace-separated chunk of that path as its own "goal" though, so the
# phony no-op rule below has to re-escape the spaces to match it as one target.
ifeq ($(GOAL),run)
RUN_GAME := $(firstword $(ARGS))
RUN_EXE := $(wordlist 2,$(words $(ARGS)),$(ARGS))
PHONY_GOALS := $(strip $(RUN_GAME) $(subst $(space),\ ,$(RUN_EXE)))
else
PHONY_GOALS := $(ARGS)
endif

ifneq ($(filter init install run config clean,$(GOAL)),)
ifneq ($(strip $(PHONY_GOALS)),)
$(eval $(PHONY_GOALS):;@:)
endif
endif

help:
	@echo "Usage:"
	@echo "  make init <game_name>                     create a wine prefix for <game_name>"
	@echo "  make install <game_name> <exe> [launch]    run an installer/exe inside the prefix"
	@echo "  make run <game_name> [exe]                 launch the recorded game executable, or [exe] inside its prefix"
	@echo "  make config <game_name> [key] [value]      view or set an option in config.json"
	@echo "  make list                                  list known games"
	@echo "  make clean <game_name>                     delete one game's directory, incl. prefix (asks to confirm)"
	@echo "  make clean                                 delete ALL games' directories (asks to confirm)"
	@echo
	@echo "If a path contains spaces, use variables instead of positional args:"
	@echo "  make install GAME=<game_name> EXE='/path/with spaces/setup.exe' [LAUNCH='...']"
	@echo "  make run GAME=<game_name> EXE='/path/with spaces/game.exe'"
	@echo
	@echo "Env:"
	@echo "  WINEARCH=win32|win64   arch used by 'make init' (default: win64)"
	@echo "  GAMESCOPE_ARGS='...'   flags passed to gamescope for 'make run'"
	@echo "  NO_GAMESCOPE=1         skip gamescope and launch wine directly"
	@echo "  GAMESCOPE_FORCE_GRAB_CURSOR=0   disable the default --force-grab-cursor gamescope flag"

init:
	@scripts/init.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

install:
	@scripts/install.sh $(if $(GAME),$(call qv,$(GAME)) $(call qv,$(EXE)) $(if $(LAUNCH),$(call qv,$(LAUNCH))),$(QARGS))

run:
	@scripts/run.sh $(if $(GAME),$(call qv,$(GAME)),$(call qv,$(RUN_GAME))) $(if $(EXE),$(call qv,$(EXE)),$(if $(RUN_EXE),$(call qv,$(RUN_EXE))))

config:
	@scripts/config.sh $(if $(GAME),$(call qv,$(GAME)) $(if $(KEY),$(call qv,$(KEY)) $(if $(VALUE),$(call qv,$(VALUE)))),$(QARGS))

list:
	@if [ -d games ] && [ -n "$$(ls -A games 2>/dev/null | grep -v '^\.gitkeep$$')" ]; then \
		find games -mindepth 1 -maxdepth 1 -type d -printf '%f\n'; \
	else \
		echo "No games yet. Run 'make init <game_name>' first."; \
	fi

clean:
	@scripts/clean.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))
