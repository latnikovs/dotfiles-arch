# dotfiles-arch

My Arch Linux desktop: Hyprland (configured in Lua) with a Quickshell bar, Nord
light and dark themes, zsh, tmux and Neovim. Modelled on
[Omarchy](https://github.com/omacom/omarchy).

Each top-level directory is a [GNU Stow](https://www.gnu.org/software/stow/)
package that mirrors `$HOME`; `install.sh` installs the packages in
`packages.txt`, stows everything and sets up the system services.

## Installing on a new machine

### 1. Arch Linux

Install Arch with `archinstall`. The choices that matter here:

- **Disk encryption: yes (LUKS).** On an encrypted disk the first login of
  each boot is automatic, since the disk password already identified you.
- **Network: NetworkManager**, or plug in Ethernet for the first run.
  `install.sh` moves the machine to NetworkManager and carries over Wi-Fi
  networks saved by iwd, but enterprise and WPA3-only networks don't come
  across.
- A user account in the `wheel` group with `sudo`. No desktop profile
  is needed.

### 2. Run the installer

Log in on the console, then:

```sh
curl -fsSL https://raw.githubusercontent.com/latnikovs/dotfiles-arch/main/install.sh | bash
```

It installs git, clones this repo to `~/dotfiles` and carries on from there.
Everything it prints also goes to `~/install.log`.

The script asks for your password a few times (`sudo`, `chsh`). It stops at
the first error. Most of it can safely be run again, so fix the problem and
rerun it, either the same way or as `~/dotfiles/install.sh`. It ends by
switching to NetworkManager, which drops the connection for a few seconds.

Then reboot. You should get the login screen (or, with an encrypted disk,
land straight in Hyprland).

The UTM virtual machine I use for testing installs with
`~/dotfiles/install.sh utm-vm` (or `… | bash -s -- utm-vm`), which adds
`machines/utm-vm.*` (see below).

### 3. By hand, afterwards

- Copy over the KeePassXC database and SSH keys, then switch the remote to SSH:
  `git remote set-url origin git@github.com:latnikovs/dotfiles-arch.git`
- `tailscale up --operator=$USER`, so the bar can drive Tailscale without `sudo`
- Add the Mac's public key to `~/.ssh/authorized_keys`. The SSH server only
  accepts keys, and the firewall only lets it in over Tailscale.
- `gh auth login`
- Sign in to Thunderbird (SUPER+M) and Teams (SUPER+Y)
- Pair Syncthing with the other machines (below)

### Syncthing

`~/notes` and `~/Documents` sync between my machines with Syncthing, over
Tailscale only: no discovery servers, relays or LAN broadcasts, and paired
devices may connect only from Tailscale addresses. `install.sh` sets up the
Linux side with `syncthing/setup`, which prints this machine's device ID.
Replaced and deleted files stay in each folder's `.stversions` for 90 days.
Syncthing isn't a backup, since deletions sync too.

On the Mac (not managed by this repo), once:

```sh
brew install syncthing && brew services start syncthing
curl -fsSL https://raw.githubusercontent.com/latnikovs/dotfiles-arch/main/syncthing/setup | bash
```

Keep `~/Documents` out of iCloud Drive ("Desktop & Documents Folders" off)
before syncing it. iCloud swaps files it offloads for placeholders, and those
would sync as missing.

Then pair each pair of machines on both sides, using Tailscale names and the IDs
the setup printed (`syncthing cli show system` shows them again):

```sh
~/dotfiles/syncthing/setup pair dmbp <Mac's device ID>        # on Linux
curl -fsSL …/syncthing/setup | bash -s -- pair archvm <its ID>  # on the Mac
```

The first sync merges the folders: files only one side has are copied to the
other, and files both have but with different contents keep both versions (one as
`*.sync-conflict-*`). The web UI is at http://127.0.0.1:8384.

## If something breaks

- **No desktop after login:** switch to another console with Ctrl+Alt+F2 and
  log in there. Hyprland only starts on tty1.
- **Login screen broken:** if the Quickshell greeter fails to load, tuigreet
  takes over on the console. To go back to a plain console login on tty1:
  `sudo systemctl disable greetd`, then reboot. Logs are in
  `journalctl -b -u greetd`.
- **No network:** `nmtui`.

## Using it

- **SUPER+/** lists every keybinding.
- SUPER+RETURN opens a terminal, SUPER+SPACE the app launcher and SUPER+ESC
  the system menu (lock, suspend, log out, restart, shut down).
- SUPER+`hjkl` moves focus between windows, as in Vim; SUPER+SHIFT+`hjkl` swaps them.

## Layout

| Path | What it is |
|---|---|
| `hypr/` | Hyprland (`hyprland.lua`), lock screen, idle, night light, and the scripts behind the binds |
| `quickshell/` | Bar, notifications, dropdown panels, polkit prompt |
| `greeter/` | Login screen: greetd runs a separate Hyprland with a Quickshell greeter (installed to `/etc/greetd`) |
| `console/` | Nord colours for the Linux console |
| `machines/` | Per-machine overrides: `./install.sh <name>` installs `machines/<name>.lua` as `~/.config/hypr/local.lua`, plus `<name>.mise.toml` and `<name>.greeter.lua` if they exist |
| `browser-policies/`, `keepassxc/` | Copied into place by `install.sh` rather than stowed |
| `syncthing/` | `setup`: Syncthing over Tailscale only, pairing (run, not stowed) |
| `packages.txt` | Packages from the official repos; AUR packages are installed in `install.sh` |
| everything else | One Stow package per program (`zsh/`, `tmux/`, `nvim/`, `kitty/`, …) |

Shared config must work on its own on a real machine; workarounds for a
particular machine go in `machines/`.
