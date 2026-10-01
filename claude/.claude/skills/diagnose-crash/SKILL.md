---
name: diagnose-crash
description: >
  Diagnose why a program crashed on this machine, from a systemd-coredump core dump.
  Use when a process has segfaulted, aborted, or otherwise dumped core, when asked
  why an application crashed or disappeared, or when "Diagnose" is clicked in the
  bar's crash list. Triggers: crash, segfault, SIGSEGV, SIGABRT, core dump,
  coredumpctl, "why did X crash", "X keeps crashing", backtrace symbolization.
---

# Diagnosing a Crash

Adapted from Omarchy's diagnose-crash skill. Work from evidence. The goal is an
honest account of what happened, not a plausible-sounding story.

This machine runs Arch Linux with Hyprland and a Quickshell bar, configured from
the stow packages in `~/dotfiles`. The bar lists crashes from systemd-coredump
(`quickshell/.config/quickshell/Crashes.qml`).

## Establish the facts

`coredumpctl info <pid>` is the starting point. Beyond the backtrace, note the
**command line** the process was started with. It usually shows what the program
was working on when it died, and that is often the whole answer.

`coredumpctl list` shows whether this crash is a one-off or a pattern. Repeated
crashes of the same program, or several programs dying together (for example when
Hyprland restarts or the session ends), point somewhere different than a single
failure does.

## Rule out the boring causes first

Check resource exhaustion before blaming the program: `free -h`, and the journal
for OOM kills. A process killed by the OOM killer is not a bug in that process.

## Correlate against the timeline

The crash timestamp is the most underused piece of evidence. Compare it against:

- **The journal** around that moment (`journalctl --since … --until …`), for
  related warnings from the same or neighbouring processes.
- **Recent package updates** (`/var/log/pacman.log`). A crash that starts right
  after an update points at the update.
- **Recent config changes**: `git -C ~/dotfiles log --since=…`, and file mtimes.
  A file or directory whose mtime lands on the same second as the crash strongly
  suggests what triggered it.

## Read the whole core, not just frame 0

Thread stacks other than the crashing one show what work was **in flight**:
thumbnailers, image loaders, IPC readers, GPU queues. That context often explains
the trigger even when the crashing frame itself cannot be symbolized.

Note any third-party code in the address space: plugins, extensions, out-of-tree
drivers. In-process third-party code is a common crash source and worth flagging,
but do not pin blame on it without evidence that it is actually implicated.

## Symbolize when you can

Arch runs a public debuginfod server:

```bash
core=$(mktemp -t crash-XXXXXX.core)
trap 'rm -f "$core"' EXIT
coredumpctl dump <pid> --output="$core"
DEBUGINFOD_URLS="https://debuginfod.archlinux.org" \
  gdb -q <executable> "$core" \
  -batch -ex 'set debuginfod enabled on' -ex 'thread apply all bt'
```

A core is a verbatim copy of the process's memory and can hold passwords, tokens,
and private documents. Write it to a fresh `mktemp` path rather than a predictable
shared one, and delete it when you are done. Never leave it lying in `/tmp`.

If `coredumpctl` reports the core as missing (too big, or already rotated away),
work from the stack trace and fields that `coredumpctl info` still has, and say so.

Many packages publish no debug symbols. When frames stay unresolved, say so, and
never invent function names to fill the gap. An unsymbolized stack still has
shape: which library each frame belongs to, and whether the crash came from a
signal handler, a main loop, or a worker thread.

## Report

1. What crashed, and what it was doing at the time.
2. The most likely mechanism, separating clearly what the evidence **proves**
   from what you are **inferring**.
3. Whether any user data was lost, and where it can be recovered from. Check the
   trash before concluding anything is gone.
4. Whether it is likely to recur, and what would avoid or fix it.

Be straight about the limits of the evidence. If the cause is genuinely
ambiguous, say so rather than building confidence out of guesswork.

**Leave the system as you found it.** Diagnosis reads. It does not fix, tidy, or
reconfigure anything unless the user asks. The one thing to clean up is your own:
delete the core you extracted above.

## Whose bug is it?

- **The dotfiles** (Hyprland config, the Quickshell bar, the scripts in
  `~/dotfiles`): name the file and the likely fix, and offer to make it.
- **Anything else** (an application, a library, Hyprland or Quickshell
  themselves): say which upstream project it belongs to. If it looks worth
  reporting, search that project's issue tracker for a match first (including
  closed issues: a fixed bug that still reproduces is a regression). Then draft
  the report for the user to submit. Never file anything yourself.

## Stop listing a program

The user dismisses a crash from the bar's crash list, and it comes back only if
that program crashes again. If a program keeps crashing and nothing can be done
about it, offer to add its name to `ignore` in
`~/dotfiles/quickshell/.config/quickshell/Crashes.qml`, and never do it
unprompted. Use the binary's basename (the list shows that), not the 15-character
process name. Say how to undo it: remove the name from `ignore` again. A program
run through an interpreter is listed as the interpreter, so ignoring `python3.13`
would hide every Python crash; say so rather than quietly doing it. An ignore
entry hides the crash and fixes nothing, so it is the wrong answer when a fix is
within reach.
