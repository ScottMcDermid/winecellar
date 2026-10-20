SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help init install run list

# Allow positional args after the subcommand, e.g.:
#   make init mygame
#   make install mygame setup.exe
#   make run mygame
GOAL := $(firstword $(MAKECMDGOALS))
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

ifneq ($(filter init install run,$(GOAL)),)
$(eval $(ARGS):;@:)
endif

help:
	@echo "Usage:"
	@echo "  make init <game_name>                     create a wine prefix for <game_name>"
	@echo "  make install <game_name> <exe> [launch]    run an installer/exe inside the prefix"
	@echo "  make run <game_name>                       launch the recorded game executable"
	@echo "  make list                                  list known games"
	@echo
	@echo "Env:"
	@echo "  WINEARCH=win32|win64  arch used by 'make init' (default: win64)"

init:
	@scripts/init.sh $(ARGS)

install:
	@scripts/install.sh $(ARGS)

run:
	@scripts/run.sh $(ARGS)

list:
	@if [ -d games ] && [ -n "$$(ls -A games 2>/dev/null | grep -v '^\.gitkeep$$')" ]; then \
		find games -mindepth 1 -maxdepth 1 -type d -printf '%f\n'; \
	else \
		echo "No games yet. Run 'make init <game_name>' first."; \
	fi
