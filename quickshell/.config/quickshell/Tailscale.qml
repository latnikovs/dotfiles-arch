// Tailscale, from `tailscale status --json`: polled every 5s, every second while its dropdown
// is open. Commands run as the user, whom install.sh makes tailscaled's operator.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: tailscale

    // False without tailscaled (not installed or not running); the bar hides its icon then
    property bool available: false
    // Running, Stopped, NeedsLogin, NeedsMachineAuth, Starting, NoState
    property string backendState: ""
    readonly property bool running: backendState === "Running"
    property var self: null
    // Online first, then by name
    property var peers: []
    readonly property var exitNode: peers.find(p => p.ExitNode) ?? null
    readonly property var exitNodeOptions: peers.filter(p => p.ExitNodeOption)
    property string tailnet: ""
    // Set by the dropdown while it's open
    property bool watching: false

    // First line of the last command's error, cleared by the next command
    property string error: ""
    readonly property bool busy: command.running
    readonly property bool loggingIn: login.running
    // Login page of the running `tailscale up`
    property string authUrl: ""

    // MagicDNS name without the tailnet, else the host name
    function nameOf(node): string {
        return node?.DNSName ? node.DNSName.split(".")[0] : node?.HostName ?? "";
    }

    function ipv4Of(node): string {
        return (node?.TailscaleIPs ?? []).find(ip => ip.includes(".")) ?? "";
    }

    function refresh(): void {
        status.running = true;
    }

    function run(args: var): void {
        if (command.running)
            return;
        error = "";
        command.command = ["tailscale", ...args];
        command.running = true;
    }

    function setRunning(on: bool): void {
        run([on ? "up" : "down"]);
    }

    // An empty name stops using an exit node
    function useExitNode(ip: string): void {
        run(["set", `--exit-node=${ip}`]);
    }

    // `tailscale up` prints a login URL and waits until it's been visited
    // Again while it waits: the same page, since restarting would make a new one
    function startLogin(): void {
        if (login.running && authUrl !== "") {
            Quickshell.execDetached(["xdg-open", authUrl]);
            return;
        }
        error = "";
        authUrl = "";
        login.running = true;
    }

    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", text]);
    }

    Process {
        id: status
        // Through sh, so a machine without tailscale doesn't log a failed start every poll
        command: ["sh", "-c", "command -v tailscale >/dev/null && exec tailscale status --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s;
                try {
                    s = JSON.parse(text);
                } catch (e) {
                    tailscale.available = false;
                    return;
                }
                tailscale.available = true;
                tailscale.backendState = s.BackendState ?? "";
                tailscale.self = s.Self ?? null;
                tailscale.tailnet = s.CurrentTailnet?.Name ?? "";
                tailscale.peers = Object.values(s.Peer ?? {}).sort((a, b) => b.Online - a.Online || tailscale.nameOf(a).localeCompare(tailscale.nameOf(b)));
            }
        }
    }

    Process {
        id: command
        stderr: StdioCollector {
            onStreamFinished: {
                const line = text.trim().split("\n")[0];
                if (line !== "")
                    tailscale.error = line;
            }
        }
        onExited: tailscale.refresh()
    }

    Process {
        id: login
        // Not `tailscale login`, which adds a new profile (without the operator setting).
        // --operator because up without it would clear the setting
        command: ["tailscale", "up", `--operator=${Quickshell.env("USER")}`]
        stdout: SplitParser {
            onRead: line => login.openUrl(line)
        }
        stderr: SplitParser {
            onRead: line => login.openUrl(line)
        }
        // Whether it worked shows in the state, so the exit code isn't reported
        onExited: tailscale.refresh()

        function openUrl(line) {
            const url = /https:\/\/\S+/.exec(line)?.[0];
            if (url) {
                tailscale.authUrl = url;
                Quickshell.execDetached(["xdg-open", url]);
            }
            else if (/denied|error|failed/i.test(line))
                tailscale.error = line.trim();
        }
    }

    Timer {
        interval: tailscale.watching || tailscale.loggingIn ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: tailscale.refresh()
    }
}
