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
- **Filesystem: Btrfs**, with archinstall's default subvolumes and
  compression. `install.sh` then sets up snapshots of `/` (not `/home`)
  before and after every package update, as Omarchy does.
- **Bootloader: Limine.** Each snapshot then gets a boot menu entry, so an
  update that breaks the system can be undone: boot the snapshot from the
  menu, then click the notification to restore it (or *Menu › Snapshots ›
  Restore booted snapshot*). On another bootloader the snapshots are still
  taken, but restoring them is up to you.
- **Boot partition: 2 GiB or more**, if you partition by hand. Each snapshot
  entry keeps its own kernel there; with archinstall's 1 GiB only the
  newest few fit, and the oldest entries make room automatically.
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
The terminal shows one line per step; every command and all it prints go to
`~/.local/state/dotfiles/install.log` (the latest run, with the nine before it
kept beside it). `DOTFILES_ICONS=nerd|unicode|ascii` overrides the icons it
picks for the terminal, `NO_COLOR=1` turns colours off.

The script asks for your `sudo` password once, at the start. It stops at the
first error and shows the end of the failed step's log. Most of it can safely
be run again, so fix the problem and rerun it, either the same way or as
`~/dotfiles/install.sh`. It ends by switching to NetworkManager, which drops
the connection for a few seconds.

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

If iCloud Drive syncs the Mac's Desktop & Documents, keep all of `~/Documents`
downloaded before syncing it: in Finder, right-click Documents → Keep
Downloaded (macOS 15+), or turn off Optimize Mac Storage at the bottom of System
Settings → your name → iCloud. Otherwise iCloud swaps files it offloads for
placeholders, and those would sync as missing. iCloud stays on, so Documents
still reach the iPhone; an edit on the phone and one on Linux before either
has synced leaves a conflict copy (iCloud's `name 2.ext`).

Then pair each pair of machines on both sides, using Tailscale names and the IDs
the setup printed (`syncthing cli show system` shows them again):

```sh
# on Linux
~/dotfiles/syncthing/setup pair dmbp <Mac's device ID>
# on the Mac
curl -fsSL https://raw.githubusercontent.com/latnikovs/dotfiles-arch/main/syncthing/setup | bash -s -- pair archvm <its ID>
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
- SUPER+ALT+SPACE opens the menu, as in Omarchy: apps, web apps,
  screenshots and screen recordings, toggles (caffeine, do not disturb, night
  light, light/dark), reminders, the bar's panels, updates, snapshots and the
  system menu. Esc in a submenu goes back.
- *Menu › Web apps* adds a site to the app launcher as an app of its own (a
  Chromium app window with the site's icon), as Omarchy does.
- SUPER+SHIFT+R (or CTRL+Print) records a screen region into
  `~/Videos/Screencasts`; the bar shows a red dot until you press it again
  or click the dot. *Menu › Capture* also records with sound, or a whole monitor.
- Printing: printers on the local network show up in print dialogs by
  themselves (modern ones need no driver); *Print Settings* in the app
  launcher adds others, such as USB printers.
- The brightness keys dim a laptop panel, or an external monitor through
  its own setting (DDC/CI, which has to be on in the monitor's menu).
- SUPER+`hjkl` moves focus between windows, as in Vim; SUPER+SHIFT+`hjkl` swaps them.

## Layout

| Path | What it is |
|---|---|
| `hypr/` | Hyprland (`hyprland.lua`), lock screen, idle, night light, and the scripts behind the binds |
| `quickshell/` | Bar, notifications, dropdown panels, polkit prompt |
| `greeter/` | Login screen: greetd runs a separate Hyprland with a Quickshell greeter (installed to `/etc/greetd`) |
| `console/` | Nord colours for the Linux console |
| `limine/` | The Limine boot menu's look (Nord), put on the boot partition by `install.sh` when Limine is the bootloader |
| `machines/` | Per-machine overrides: `./install.sh <name>` installs `machines/<name>.lua` as `~/.config/hypr/local.lua`, plus `<name>.mise.toml` and `<name>.greeter.lua` if they exist |
| `browser-policies/`, `keepassxc/` | Copied into place by `install.sh` rather than stowed |
| `syncthing/` | `setup`: Syncthing over Tailscale only, pairing (run, not stowed) |
| `packages.txt` | Packages from the official repos; AUR packages are installed in `install.sh` |
| everything else | One Stow package per program (`zsh/`, `tmux/`, `nvim/`, `kitty/`, …) |

Shared config must work on its own on a real machine; workarounds for a
particular machine go in `machines/`.
