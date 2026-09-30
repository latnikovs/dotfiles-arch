// Top processes dropdown, from the CPU or RAM figure (left click): the ten busiest, highest first,
// refreshed every 2s while open. CPU is each process's share of all cores over a 1s sample from
// top (so the rows add up to the bar figure); RAM is its resident memory from ps, with the share
// of total RAM.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Dropdown {
    id: panel

    property bool memory: false
    property string title: ""
    property var processes: []
    property bool loaded: false

    panelWidth: 360

    // Tab-separated: pid, percent, resident KiB (RAM only), name. top's first frame averages
    // since each process started, so the second frame is the one read.
    readonly property string script: memory
        ? "LC_ALL=C ps -eo pid=,pmem=,rss=,comm= --sort=-rss | head -10"
            + " | awk '{ c = $4; for (i = 5; i <= NF; i++) c = c \" \" $i; print $1 \"\\t\" $2 \"\\t\" $3 \"\\t\" c }'"
        : "LC_ALL=C top -b -n 2 -d 1 -o %CPU -w 512 | awk -v n=$(nproc) '"
            + "/^top -/ { f++ } f == 2 && h && k < 10 { c = $12; for (i = 13; i <= NF; i++) c = c \" \" $i;"
            + " printf \"%s\\t%.1f\\t\\t%s\\n\", $1, $9 / n, c; k++ } f == 2 && $1 == \"PID\" { h = 1 }'"

    function size(kib) {
        if (kib >= 1048576)
            return `${(kib / 1048576).toFixed(1)}G`;
        if (kib >= 1024)
            return `${Math.round(kib / 1024)}M`;
        return `${kib}K`;
    }

    onOpenChanged: {
        if (open)
            proc.running = true;
        else
            loaded = false;
    }

    Process {
        id: proc
        command: ["sh", "-c", panel.script]
        stdout: StdioCollector {
            onStreamFinished: {
                panel.processes = text.trim().split("\n").filter(l => l !== "").map(l => {
                    const [pid, percent, kib, name] = l.split("\t");
                    return { pid, percent: Number(percent), kib: Number(kib), name };
                });
                panel.loaded = true;
            }
        }
    }

    Timer {
        interval: 2000
        running: panel.open && !proc.running
        onTriggered: proc.running = true
    }

    ColumnLayout {
        width: parent.width
        spacing: 10

        BarText {
            Layout.fillWidth: true
            text: panel.title
            font.bold: true
        }

        Caption {
            text: panel.loaded ? (panel.memory ? "TOP PROCESSES BY MEMORY" : "TOP PROCESSES BY CPU") : "MEASURING…"
        }

        // Name and pid on the left, then the resident size (RAM) and the percentage
        Repeater {
            model: panel.loaded ? panel.processes : []

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 12

                BarText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    textFormat: Text.StyledText
                    text: `${modelData.name} <font color="${Theme.dim}">${modelData.pid}</font>`
                }

                BarText {
                    visible: panel.memory
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignRight
                    text: panel.size(modelData.kib)
                }

                BarText {
                    Layout.preferredWidth: 48
                    horizontalAlignment: Text.AlignRight
                    text: `${modelData.percent.toFixed(1)}%`
                    color: modelData.percent >= 50 ? Theme.urgent : Theme.fg
                }
            }
        }
    }
}
