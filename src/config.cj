package FSD_Cangjie

import std.collection.*
import std.fs.*

public class ConfigEntry {
    var data: String; var parts: Array<String>; var nparts: Int32
    public init(data: String) { this.data = data; this.parts = splitStr(data, ","); this.nparts = Int32(this.parts.size) }
    public func getData(): String { return this.data }
    public func getInt(): Int32 { return parseInt32(this.data.trim()) }
    public func getNparts(): Int32 { return this.nparts }
    public func getPart(index: Int32): String {
        let idx: Int64 = Int64(index)
        if (idx >= 0 && idx < this.parts.size) { return this.parts[idx].trim() }
        return ""
    }
}

public class ConfigGroup {
    var name: String; var entries: HashMap<String, ConfigEntry>; var changed: Bool
    public init(name: String) { this.name = name; this.entries = HashMap<String, ConfigEntry>(); this.changed = false }
    public func getEntry(key: String): ?ConfigEntry { return this.entries.get(key) }
    public func createEntry(key: String, value: String): ConfigEntry { let e = ConfigEntry(value); this.entries[key] = e; return e }
}

public class ConfigManager {
    var groups: HashMap<String, ConfigGroup>; var filename: String; var prevCheck: Int64
    var lastContent: String

    public init(filename: String) {
        this.groups = HashMap<String, ConfigGroup>(); this.filename = filename; this.prevCheck = 0; this.lastContent = ""
        parseFile()
    }

    private func parseFile(): Unit {
        var content = readFileStr(this.filename)
        if (content == "") { return }
        this.lastContent = content
        var currentGroup: ?String = None
        for (line in splitStr(content, "\n")) {
            let trimmed = rmComment(line).trim()
            if (trimmed == "") { continue }
            if (trimmed.toRuneArray()[0] == r'[') {
                match (trimmed.indexOf(r']')) {
                    case Some(e) => let n = substr(trimmed, 1, e); this.groups[n] = ConfigGroup(n); currentGroup = n
                    case None => ()
                }
                continue
            }
            match (trimmed.indexOf(r'=')) {
                case Some(e) =>
                    let k = substrTo(trimmed, e).trim(); let v = substrFrom(trimmed, e + 1).trim()
                    match (currentGroup) { case Some(gn) => match (this.groups.get(gn)) { case Some(g) => g.createEntry(k, v); case None => () }; case None => () }
                case None => ()
            }
        }
    }

    private func rmComment(line: String): String {
        match (line.indexOf(r';')) { case Some(i) => return substrTo(line, i); case None =>
            match (line.indexOf(r'#')) { case Some(i) => return substrTo(line, i); case None => return line }
        }
    }

    private func readFileStr(path: String): String {
        try {
            let bytes = File.readFrom(Path(path))
            return String.fromUtf8(bytes)
        } catch (e: Exception) {
            return ""
        }
    }

    public func getGroup(name: String): ?ConfigGroup { return this.groups.get(name) }
    public func run(): Int32 {
        let now = mgmtime()
        if ((now - this.prevCheck) > CONFIGINTERVAL) {
            this.prevCheck = now
            let newContent = readFileStr(this.filename)
            if (newContent != "" && newContent != this.lastContent) {
                dolog(L_INFO, "Config file changed, reloading...")
                this.groups = HashMap<String, ConfigGroup>()
                this.lastContent = newContent
                var currentGroup: ?String = None
                for (line in splitStr(newContent, "\n")) {
                    let trimmed = rmComment(line).trim()
                    if (trimmed == "") { continue }
                    if (trimmed.toRuneArray()[0] == r'[') {
                        match (trimmed.indexOf(r']')) {
                            case Some(e) => let n = substr(trimmed, 1, e); this.groups[n] = ConfigGroup(n); currentGroup = n
                            case None => ()
                        }
                        continue
                    }
                    match (trimmed.indexOf(r'=')) {
                        case Some(e) =>
                            let k = substrTo(trimmed, e).trim(); let v = substrFrom(trimmed, e + 1).trim()
                            match (currentGroup) { case Some(gn) => match (this.groups.get(gn)) { case Some(g) => g.createEntry(k, v); case None => () }; case None => () }
                        case None => ()
                    }
                }
            }
        }
        return 0
    }
}
