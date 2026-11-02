# Checks to run before committing: `make lint` (or plain `make`).
# Tools: shellcheck and stylua from mise (mise/.config/mise/config.toml), qmllint from
# qt6-declarative (a Quickshell dependency), hyprland, luac, zsh and jq from the repos.

SHELL := /bin/bash
.SHELLFLAGS := -eo pipefail -c
.DEFAULT_GOAL := lint

QMLLINT := /usr/lib/qt6/bin/qmllint

LUA_FILES = $(shell git ls-files '*.lua')
QML_FILES = $(shell git ls-files '*.qml')
JSON_FILES = $(shell git ls-files '*.json')
ZSH_FILES = zsh/.zshrc zsh/.zprofile

.PHONY: lint shellcheck qml hyprland lua zsh json

lint: shellcheck qml hyprland lua zsh json
	@echo "lint: all checks passed"

# Every tracked file that starts with a sh or bash shebang
shellcheck:
	@mapfile -t files < <(git ls-files | while IFS= read -r f; do \
		[[ -f $$f ]] && head -1 "$$f" | grep -qE '^#!.*[/ ](ba)?sh$$' && printf '%s\n' "$$f"; done); \
	echo "shellcheck: $${#files[@]} scripts"; \
	shellcheck -S warning "$${files[@]}"

# Fails only on what Quickshell couldn't load (syntax errors); qmllint's other warnings
# are mostly noise, since Quickshell's types aren't fully described for it. They print
# with `make qml QMLLINT_ARGS=`.
QMLLINT_ARGS ?= --unqualified disable --missing-property disable --unresolved-type disable \
	--uncreatable-type disable --import disable --unused-imports disable \
	--id-shadows-member disable --syntax disable
qml:
	@echo "qmllint: $(words $(QML_FILES)) files"
	@$(QMLLINT) $(QMLLINT_ARGS) $(QML_FILES)

# The config as Hyprland itself reads it; the main one also runs local.lua, if installed
hyprland:
	@for f in hypr/.config/hypr/hyprland.lua greeter/hyprland.lua; do \
		echo "hyprland --verify-config: $$f"; \
		out=$$(hyprland --verify-config -c "$$f" 2>&1) || { echo "$$out" | sed -n '/parsing result/,$$p'; exit 1; }; \
	done

lua:
	@echo "luac -p: $(words $(LUA_FILES)) files; stylua: nvim"
	@luac -p $(LUA_FILES)
	@stylua --check nvim/.config/nvim

zsh:
	@echo "zsh -n: $(ZSH_FILES)"
	@for f in $(ZSH_FILES); do zsh -n "$$f"; done

json:
	@echo "jq: $(words $(JSON_FILES)) files"
	@for f in $(JSON_FILES); do jq empty "$$f" || { echo "invalid JSON: $$f"; exit 1; }; done
