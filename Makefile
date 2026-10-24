SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help
# `-C` (as in `make -C /path/to/winecellar completion`) implicitly turns on
# `-w`/--print-directory, which prints "make: Entering/Leaving directory
# '...'" lines to stdout around the recipe's own output. Harmless normally,
# but fatal for `completion`/`completion-zsh`, whose output is meant to be
# eval'd as shell: those two lines would get eval'd right along with it.
MAKEFLAGS += --no-print-directory

.PHONY: help init install run launch tool regedit config list menu clean kill logs completion completion-zsh

space := $(empty) $(empty)

# Allow positional args after the subcommand, e.g.:
#   make init mygame
#   make install mygame setup.exe
#   make run mygame
#   make launch mygame
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

# `run`/`launch` only ever take two logical positional args (game_name, exe),
# so unlike config they can safely treat everything after the first word as
# a single reconstructed exe path, spaces and all. `install` is the same
# idea: a positional launch-override 3rd arg would be ambiguous once the exe
# path itself can contain spaces, so it's dropped from the positional form
# entirely - use LAUNCH= for that. `tool` keeps its 3rd arg, but only because
# the word in between (tool_name) is never expected to contain spaces.
# Make still parses each whitespace-separated chunk of that path as its own
# "goal" though, so the phony no-op rule below has to re-escape the spaces
# to match it as one target.
ifneq ($(filter run launch,$(GOAL)),)
RUN_GAME := $(firstword $(ARGS))
RUN_EXE := $(wordlist 2,$(words $(ARGS)),$(ARGS))
PHONY_GOALS := $(strip $(RUN_GAME) $(subst $(space),\ ,$(RUN_EXE)))
else ifeq ($(GOAL),install)
INSTALL_GAME := $(firstword $(ARGS))
INSTALL_EXE := $(wordlist 2,$(words $(ARGS)),$(ARGS))
PHONY_GOALS := $(strip $(INSTALL_GAME) $(subst $(space),\ ,$(INSTALL_EXE)))
else ifeq ($(GOAL),tool)
TOOL_GAME := $(firstword $(ARGS))
TOOL_NAME := $(word 2,$(ARGS))
TOOL_EXE := $(wordlist 3,$(words $(ARGS)),$(ARGS))
PHONY_GOALS := $(strip $(TOOL_GAME) $(TOOL_NAME) $(subst $(space),\ ,$(TOOL_EXE)))
else
PHONY_GOALS := $(ARGS)
endif

ifneq ($(filter init install run launch tool regedit config clean kill logs,$(GOAL)),)
ifneq ($(strip $(PHONY_GOALS)),)
$(eval $(PHONY_GOALS):;@:)
endif
endif

help:
	@scripts/help.sh

completion:
	@scripts/completion.sh

completion-zsh:
	@scripts/completion-zsh.sh

init:
	@scripts/init.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

install:
	@scripts/install.sh $(if $(GAME),$(call qv,$(GAME)),$(call qv,$(INSTALL_GAME))) $(if $(EXE),$(call qv,$(EXE)),$(if $(INSTALL_EXE),$(call qv,$(INSTALL_EXE)))) $(if $(LAUNCH),$(call qv,$(LAUNCH)))

run:
	@scripts/run.sh $(if $(GAME),$(call qv,$(GAME)),$(call qv,$(RUN_GAME))) $(if $(EXE),$(call qv,$(EXE)),$(if $(RUN_EXE),$(call qv,$(RUN_EXE))))

launch: run
	@:

tool:
	@scripts/tool.sh $(if $(GAME),$(call qv,$(GAME)),$(call qv,$(TOOL_GAME))) $(if $(TOOL),$(call qv,$(TOOL)),$(if $(TOOL_NAME),$(call qv,$(TOOL_NAME)))) $(if $(EXE),$(call qv,$(EXE)),$(if $(TOOL_EXE),$(call qv,$(TOOL_EXE))))

regedit:
	@scripts/regedit.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

config:
	@scripts/config.sh $(if $(GAME),$(call qv,$(GAME)) $(if $(KEY),$(call qv,$(KEY)) $(if $(VALUE),$(call qv,$(VALUE)))),$(QARGS))

list:
	@scripts/list.sh

menu:
	@scripts/menu.sh

clean:
	@scripts/clean.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

kill:
	@scripts/kill.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

logs:
	@scripts/logs.sh $(if $(GAME),$(call qv,$(GAME)) $(if $(NAME),$(call qv,$(NAME))),$(QARGS))
