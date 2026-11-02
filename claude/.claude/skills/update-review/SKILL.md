---
name: update-review
description: >
  Review a system update (pacman/yay) on this machine for what it broke or will break:
  the health check's problems, and the upstream release notes of the updated packages
  checked against the dotfiles for removed or deprecated options and APIs. Use after an
  update, when "Review with Claude" is picked after `updates run` or in the health check's
  notification, or when asked whether an update broke something. Triggers: update review,
  after update, upgrade broke, health check, deprecated after update, release notes.
---

# Reviewing an Update

The goal is a short list of what is broken or about to break because of the update,
each with evidence and a fix, before the user stumbles on it. Work from evidence: a
changelog entry is only a finding if the dotfiles use what it changed.

This machine runs Arch Linux with Hyprland (configured in Lua) and a Quickshell bar,
configured from the GNU Stow packages in `~/dotfiles` (`~/.config` files are symlinks
into it). `machines/<machine>.*` holds per-machine overrides; `install.sh` installs.

## Inputs

- `~/.local/state/dotfiles/last-update`: the update's `upgraded name (old -> new)` lines
  (also installed, removed, downgraded), from pacman's log.
- `~/.local/state/dotfiles/healthcheck.log`: the latest health check
  (`~/.config/hypr/scripts/healthcheck`). `✗` lines are problems, `·` lines notes. Run it
  again (`healthcheck`) to see the state now; the script's comments say what each check does.

Both are usually in the prompt already.

## 1. The health check's problems

For each `✗`, find the cause, not just the symptom: the failing config line, the log
lines around it, the package that changed it. For crashes use the diagnose-crash skill's
approach (`coredumpctl info`, the journal around the time). Say whether the update caused
it: a problem that predates the update (compare with the time in `last-update`) is still
worth reporting, marked as such.

A note that programs still run the version from before the update means the checks on
the running session tested the old version. Say so, and that the login check will test
the new one (or check what you can without a restart, e.g. `Hyprland --verify-config`).

## 2. Release notes against the dotfiles

Only for updated packages the dotfiles configure or script against. Find which by
searching `~/dotfiles` for the package's name, binary and config file. The usual ones:
hyprland, hyprlock, hypridle, hyprpaper, hyprsunset, xdg-desktop-portal-hyprland,
quickshell, kitty, neovim (and plugins: `nvim/.config/nvim/lazy-lock.json`), tmux, zsh,
fuzzel, satty, darkman, mise, yay, greetd, limine, snapper, pipewire, wireplumber.
Skip libraries and packages the dotfiles don't touch.

For each, read the upstream release notes for every version between old and new (not
only the newest): `gh release list -R <owner>/<repo>` and `gh release view <tag> -R ...`,
or the project's changelog or NEWS file. Look for removed, renamed or deprecated config
options, Lua or QML API changes, changed defaults and changed command-line flags. Then
search the dotfiles for each one and keep only those in use, with `file:line`.

Also check [Arch news](https://archlinux.org/news/) since the previous update for manual
interventions that touch an updated package.

## 3. Report

Lead with a table, most severe first:

| # | Problem | Evidence | Fix |
|---|---------|----------|-----|

Severity: **broken** (fails now), **breaks at next login/reboot** (the installed version
rejects it, the running one doesn't), **deprecated** (still works, will break), **note**.

Mark anything that only concerns the UTM VM (virgl, software GL, `machines/utm-vm.*`). The
real target is an x86_64 desktop, so a VM-only problem goes in the machine file, never in
shared config. Mark anything that only applies to aarch64.

End with what you checked and found nothing in, in one line, so the user knows the
coverage. Then ask which fixes to make; don't edit the dotfiles before the user agrees.
Fixes are committed to `main` in `~/dotfiles` with Conventional Commit messages (`fix(hypr): ...`).

## When nothing is wrong

Say so in two lines: the health check passed, and the release notes of the configured
packages have nothing that touches the dotfiles. Don't pad the report.
