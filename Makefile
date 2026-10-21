SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

.PHONY: help init install run launch tool config list clean

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
# so unlike install/config they can safely treat everything after the first
# word as a single reconstructed exe path, spaces and all. `tool` is the same
# idea with one extra fixed word in front (game_name, tool_name, exe). Make
# still parses each whitespace-separated chunk of that path as its own
# "goal" though, so the phony no-op rule below has to re-escape the spaces
# to match it as one target.
ifneq ($(filter run launch,$(GOAL)),)
RUN_GAME := $(firstword $(ARGS))
RUN_EXE := $(wordlist 2,$(words $(ARGS)),$(ARGS))
PHONY_GOALS := $(strip $(RUN_GAME) $(subst $(space),\ ,$(RUN_EXE)))
else ifeq ($(GOAL),tool)
TOOL_GAME := $(firstword $(ARGS))
TOOL_NAME := $(word 2,$(ARGS))
TOOL_EXE := $(wordlist 3,$(words $(ARGS)),$(ARGS))
PHONY_GOALS := $(strip $(TOOL_GAME) $(TOOL_NAME) $(subst $(space),\ ,$(TOOL_EXE)))
else
PHONY_GOALS := $(ARGS)
endif

ifneq ($(filter init install run launch tool config clean,$(GOAL)),)
ifneq ($(strip $(PHONY_GOALS)),)
$(eval $(PHONY_GOALS):;@:)
endif
endif

help:
	@scripts/help.sh

init:
	@scripts/init.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))

install:
	@scripts/install.sh $(if $(GAME),$(call qv,$(GAME)) $(call qv,$(EXE)) $(if $(LAUNCH),$(call qv,$(LAUNCH))),$(QARGS))

run:
	@scripts/run.sh $(if $(GAME),$(call qv,$(GAME)),$(call qv,$(RUN_GAME))) $(if $(EXE),$(call qv,$(EXE)),$(if $(RUN_EXE),$(call qv,$(RUN_EXE))))

launch: run
	@:

tool:
	@scripts/tool.sh $(if $(GAME),$(call qv,$(GAME)),$(call qv,$(TOOL_GAME))) $(if $(TOOL),$(call qv,$(TOOL)),$(if $(TOOL_NAME),$(call qv,$(TOOL_NAME)))) $(if $(EXE),$(call qv,$(EXE)),$(if $(TOOL_EXE),$(call qv,$(TOOL_EXE))))

config:
	@scripts/config.sh $(if $(GAME),$(call qv,$(GAME)) $(if $(KEY),$(call qv,$(KEY)) $(if $(VALUE),$(call qv,$(VALUE)))),$(QARGS))

list:
	@scripts/list.sh

clean:
	@scripts/clean.sh $(if $(GAME),$(call qv,$(GAME)),$(QARGS))
