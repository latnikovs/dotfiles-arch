// Syncthing (syncthing/setup), from its REST API on the GUI address: polled every 5s, every
// second while its dropdown is open. The API key comes from `syncthing cli`, read again
// whenever the API turns it down (Syncthing restarted with a new config).
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: syncthing

    // False while Syncthing isn't running (or isn't installed); the bar hides its icon then
    property bool available: false
    property string myId: ""
    // { id, label, path, paused, state, needBytes, needFiles, globalBytes, errors } per folder
    property var folders: []
    // { id, name, paused, connected, address, completion } per other device, by name
    property var devices: []
    // Set by the dropdown while it's open
    property bool watching: false

    readonly property bool paused: devices.length > 0 && devices.every(d => d.paused)
    readonly property int connectedCount: devices.filter(d => d.connected).length
    readonly property int errorCount: folders.reduce((n, f) => n + f.errors, 0)
    readonly property real needBytes: folders.reduce((n, f) => n + f.needBytes, 0)
    readonly property real globalBytes: folders.reduce((n, f) => n + f.globalBytes, 0)
    // Pulling from another device, or a connected one still pulling from this one
    readonly property bool downloading: folders.some(f => ["syncing", "sync-preparing"].includes(f.state))
    readonly property bool uploading: devices.some(d => d.connected && d.completion < 100)
    readonly property bool syncing: downloading || uploading
    // Of everything in the folders, how much this device has, 0–100
    readonly property int progress: globalBytes > 0 ? Math.floor(100 * (1 - needBytes / globalBytes)) : 100

    property string apiKey: ""
    property string address: "127.0.0.1:8384"

    function formatBytes(bytes: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1000 && i < units.length - 1) {
            bytes /= 1000;
            i++;
        }
        return `${bytes < 10 && i > 0 ? bytes.toFixed(1) : Math.round(bytes)} ${units[i]}`;
    }

    function openWebUi(): void {
        Quickshell.execDetached(["xdg-open", `http://${address}`]);
    }

    // Pauses or resumes every device, which stops or starts all syncing
    function setPaused(on: bool): void {
        request("POST", on ? "/rest/system/pause" : "/rest/system/resume", () => refresh());
    }

    function request(method: string, path: string, done: var): void {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (xhr.status === 200) {
                let body = null;
                try {
                    body = xhr.responseText !== "" ? JSON.parse(xhr.responseText) : null;
                } catch (e) {}
                done(body);
            } else if (xhr.status === 401 || xhr.status === 403) {
                syncthing.apiKey = "";
            } else if (xhr.status === 0) {
                syncthing.available = false;
            }
        };
        xhr.open(method, `http://${address}${path}`);
        xhr.setRequestHeader("X-API-Key", apiKey);
        xhr.send();
    }

    function refresh(): void {
        if (apiKey === "") {
            if (!credentials.running)
                credentials.running = true;
            return;
        }
        if (myId === "")
            request("GET", "/rest/system/status", s => syncthing.myId = s.myID);
        request("GET", "/rest/config", config => {
            request("GET", "/rest/system/connections", c => {
                const conns = c.connections ?? {};
                const devices = config.devices.filter(d => d.deviceID !== syncthing.myId).map(d => {
                    const old = syncthing.devices.find(o => o.id === d.deviceID);
                    return {
                        id: d.deviceID,
                        name: d.name || d.deviceID.slice(0, 7),
                        paused: d.paused,
                        connected: conns[d.deviceID]?.connected ?? false,
                        address: conns[d.deviceID]?.address ?? "",
                        completion: old?.completion ?? 100
                    };
                }).sort((a, b) => a.name.localeCompare(b.name));
                syncthing.devices = devices;
                syncthing.available = true;
                // How far each connected device is with what this one has
                for (const d of devices.filter(d => d.connected))
                    request("GET", `/rest/db/completion?device=${d.id}`, r => {
                        syncthing.devices = syncthing.devices.map(o => o.id === d.id ? Object.assign({}, o, { completion: r.completion }) : o);
                    });
            });
            const folders = config.folders.map(f => {
                const old = syncthing.folders.find(o => o.id === f.id);
                return old ? Object.assign({}, old, { label: f.label || f.id, path: f.path, paused: f.paused })
                    : { id: f.id, label: f.label || f.id, path: f.path, paused: f.paused, state: "", needBytes: 0, needFiles: 0, globalBytes: 0, errors: 0 };
            });
            syncthing.folders = folders;
            for (const f of folders)
                request("GET", `/rest/db/status?folder=${encodeURIComponent(f.id)}`, s => {
                    syncthing.folders = syncthing.folders.map(o => o.id === f.id ? Object.assign({}, o, {
                            state: s.state,
                            needBytes: s.needBytes,
                            needFiles: s.needFiles,
                            globalBytes: s.globalBytes,
                            errors: Math.max(s.errors ?? 0, s.pullErrors ?? 0)
                        }) : o);
                });
        });
    }

    // API key and GUI address (a bare port means localhost)
    Process {
        id: credentials
        command: ["sh", "-c", "command -v syncthing >/dev/null && syncthing cli config gui apikey get && syncthing cli config gui raw-address get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [key, address] = text.trim().split("\n");
                if (!key || !address) {
                    syncthing.available = false;
                    return;
                }
                syncthing.address = address.replace(/^0\.0\.0\.0:|^:/, "127.0.0.1:");
                syncthing.apiKey = key;
                syncthing.refresh();
            }
        }
    }

    Timer {
        interval: syncthing.watching ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: syncthing.refresh()
    }
}
