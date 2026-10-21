SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help init install run list clean

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
# spaces can't survive that route. GAME=/EXE=/LAUNCH= are regular Make
# variables instead and keep spaces intact, e.g.:
#   make install GAME=oblivion EXE='/path/with spaces/setup.exe'
qv = '$(subst ','\'',$(1))'

ifneq ($(filter init install run clean,$(GOAL)),)
$(eval $(ARGS):;@:)
endif

help:
	@echo "Usage:"
	@echo "  make init <game_name>                     create a wine prefix for <game_name>"
	@echo "  make install <game_name> <exe> [launch]    run an installer/exe inside the prefix"
	@echo "  make run <game_name>                       launch the recorded game executable"
	@echo "  make list                                  list known games"
	@echo "  make clean <game_name>                     delete one game's wine prefix (asks to confirm)"
	@echo "  make clean                                 delete ALL wine prefixes (asks to confirm)"
	@echo
	@echo "If a path contains spaces, use variables instead of positional args:"
	@echo "  make install GAME=<game_name> EXE='/path/with spaces/setup.exe' [LAUNCH='...']"
	@echo
	@echo "Env:"
	@echo "  WINEARCH=win32|win64   arch used by 'make init' (default: win64)"
	@echo "  GAMESCOPE_ARGS='...'   flags passed to gamescope for 'make run'"
	@echo "  NO_GAMESCOPE=1         skip gamescope and launch wine directly"

init:
	@scripts/init.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

install:
	@scripts/install.sh $(if $(GAME),$(call qv,$(GAME)) $(call qv,$(EXE)) $(if $(LAUNCH),$(call qv,$(LAUNCH))),$(QARGS))

run:
	@scripts/run.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

list:
	@if [ -d games ] && [ -n "$$(ls -A games 2>/dev/null | grep -v '^\.gitkeep$$')" ]; then \
		find games -mindepth 1 -maxdepth 1 -type d -printf '%f\n'; \
	else \
		echo "No games yet. Run 'make init <game_name>' first."; \
	fi

clean:
	@scripts/clean.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))
