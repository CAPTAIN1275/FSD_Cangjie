// sysinterface.cj — FSD 系统管理终端（telnet 管理端口）
// 参考 C 原版: sysuser.cpp / sysinterface.cpp

package FSD_Cangjie

import std.net.*
import std.time.*

public class SysInterface <: NetInterface {
    var prompt: String
    public init(port: Int32, name: String, description: String) {
        super(port, name, description); this.prompt = "FSD> "
    }
    public func setPrompt(p: String): Unit { this.prompt = p }
    public override func createUser(socket: TcpSocket): NetUser { return SysUser(socket, this) }

    public func handleCommand(user: SysUser, line: String): Unit {
        let args = splitStr(line.trim(), " ")
        if (args.size == 0) { return }
        let cmd = args[0]

        // ---- 无需认证 ----
        if (cmd == "help") {
            user.outStr += "Available commands:\r\n"
            user.outStr += "  help servers clients info time route cert\r\n"
            user.outStr += "  connect disconnect ping stat say wall\r\n"
            user.outStr += "  pwd quit metar weather\r\n"
        }
        else if (cmd == "time") { user.outStr += "${DateTime.now().format("yyyy-MM-dd HH:mm:ss")} local\r\n" }
        else if (cmd == "quit") { user.socket.close() }
        else if (cmd == "pwd") {
            if (args.size < 2) { user.outStr += "Usage: pwd <password>\r\n"; return }
            if (let Some(cm) <- configMan) {
                if (let Some(g) <- cm.getGroup("system")) {
                    if (let Some(e) <- g.getEntry("password")) {
                        if (e.getData() == args[1]) { user.isPrivileged = true; user.outStr += "Password correct\r\n" }
                        else { user.outStr += "Password incorrect\r\n" }
                    } else { user.isPrivileged = true }
                } else { user.isPrivileged = true }
            } else { user.isPrivileged = true }
        }
        // ---- 需要认证 ----
        else if (!user.isPrivileged) { user.outStr += "Not authorized. Use 'pwd <password>'.\r\n" }
        else if (cmd == "servers") {
            user.outStr += "ID         Host                      Fl Hops Lag  Name\r\n"
            user.outStr += "-------------------------------------------------------------\r\n"
            var sv = rootServer
            while (true) { match (sv) { case Some(s) =>
                user.outStr = user.outStr + "${padRight(s.ident, 10)} ${padRight(s.hostname, 25)}   ${s.lag}  ${s.name}\r\n"
                sv = s.next
            ; case None => break }}
        }
        else if (cmd == "clients") {
            user.outStr += "Call-sign    CID     Online   Type  Server     Frequency\r\n"
            user.outStr += "-----------------------------------------------------------------\r\n"
            var cl = rootClient
            while (true) { match (cl) { case Some(c) =>
                let locId = match (c.location) { case Some(l) => l.ident; case None => "?" }
                let typeStr = if (c.isAtc()) { "ATC" } else { "PILOT" }
                user.outStr += "${padRight(c.callsign, 10)}   ${padRight(c.cid, 7)}  ${typeStr} ${padRight(locId, 10)} ${c.frequency}\r\n"
                cl = c.next
            ; case None => break }}
        }
        else if (cmd == "info") {
            user.outStr += "Servers: ${serverCount()}  Clients: ${clientCount()}  Certs: ${certCount()}\r\n"
        }
        else if (cmd == "connect") {
            if (args.size < 2) {
                user.outStr += "Active connections:\r\n"
                user.outStr += "Active connections:\r\n"
                for (u in this.users) { user.outStr += "  connection\r\n" }
            } else {
                let port: Int32 = if (args.size > 2) { parseInt32(args[2]) } else { 3011 }
                serverInterface?.addUser(args[1], port, None)
                user.outStr += "Connecting to ${args[1]}:${port}...\r\n"
            }
        }
        else if (cmd == "disconnect") {
            if (args.size < 2) { user.outStr += "Usage: disconnect <fd>\r\n"; return }
            user.outStr += "Disconnected\r\n"
        }
        else if (cmd == "ping") {
            if (args.size < 2) { user.outStr += "Usage: ping <ident>\r\n"; return }
            let data = "-1 ${mgmtime()}"
            serverInterface?.sendPing(args[1], data)
            user.outStr += "Ping sent to ${args[1]}\r\n"
        }
        else if (cmd == "say") {
            if (args.size < 3) { user.outStr += "Usage: say <callsign|*|@> <message>\r\n"; return }
            var msg = ""; for (i in 2..args.size) { if (msg != "") { msg += " " }; msg += args[i] }
            serverInterface?.sendMulticast("server", args[1], msg, CL_MESSAGE)
            user.outStr += "Sent\r\n"
        }
        else if (cmd == "wall") {
            if (args.size < 2) { user.outStr += "Usage: wall <message>\r\n"; return }
            var msg = ""; for (i in 1..args.size) { if (msg != "") { msg += " " }; msg += args[i] }
            clientInterface?.broadcastToAll("#TMserver:*:${msg}\r\n")
            user.outStr += "Wall sent\r\n"
        }
        else if (cmd == "kill") {
            if (args.size < 2) { user.outStr += "Usage: kill <callsign> [reason]\r\n"; return }
            let reason = if (args.size > 2) { var r = ""; for (i in 2..args.size) { if (r != "") { r += " " }; r += args[i] }; r } else { "killed by admin" }
            match (getClient(args[1])) {
                case Some(c) => serverInterface?.sendKill(c.callsign, reason); clientInterface?.sendKillClient(c, reason); user.outStr += "Killed ${c.callsign}\r\n"
                case None => user.outStr += "Client '${args[1]}' not found\r\n"
            }
        }
        else if (cmd == "cert") {
            if (args.size < 2) {
                user.outStr += "CID        Level     Origin     Created\r\n"
                user.outStr += "----------------------------------------------\r\n"
                var cert = rootCert
                while (true) { match (cert) { case Some(c) =>
                    user.outStr += "${padRight(c.cid, 10)} ${levelName(c.level).padEnd(13)} ${padRight(c.serverIdent, 10)} ${c.created}\r\n"
                    cert = c.next
                ; case None => break }}
            } else if (args[1] == "add" && args.size >= 5) {
                let cid = args[2]; let pwd = args[3]; let level = parseInt32(args[4])
                match (getCert(cid)) {
                    case Some(_) => user.outStr += "Certificate already exists\r\n"
                    case None =>
                        let cert = Certificate(cid, pwd, level, mgmtime(), myServer?.ident ?? "local")
                        addCert(cert); serverInterface?.sendCert("*", CERT_ADD, cert, None)
                        user.outStr += "Certificate added: ${cid}\r\n"
                }
            } else if (args[1] == "delete" && args.size >= 3) {
                match (getCert(args[2])) {
                    case Some(c) => removeCert(c); serverInterface?.sendCert("*", CERT_DELETE, c, None); user.outStr += "Certificate deleted\r\n"
                    case None => user.outStr += "Certificate not found\r\n"
                }
            } else { user.outStr += "Usage: cert [add <cid> <pwd> <level> | delete <cid>]\r\n" }
        }
        else if (cmd == "route") {
            user.outStr += "ID         Next hop\r\n"
            user.outStr += "-------------------\r\n"
            var sv = rootServer
            while (true) { match (sv) { case Some(s) =>
                let dest = if (svMy(s)) { "*local*" } else { "*broadcast*" }
                user.outStr += "${padRight(s.ident, 10)} ${dest}\r\n"
                sv = s.next
            ; case None => break }}
        }
        else { user.outStr += "Unknown command: ${cmd}\r\n" }
    }
}

public class SysUser <: NetUser {
    var isPrivileged: Bool; var iface: SysInterface
    public init(socket: TcpSocket, iface: SysInterface) {
        super(socket); this.isPrivileged = false; this.iface = iface
    }
    public override func onConnect(): Unit {
        this.outStr += "${PRODUCT} v${VERSION}\r\n"
        this.outStr += "Type 'help' for available commands.\r\n"
        this.outStr += "${this.iface.prompt}"
    }
    public override func handleLine(line: String): Unit {
        this.iface.handleCommand(this, line)
        this.outStr += this.iface.prompt
    }
}

// svMy 定义在 fsd.cj，此处不重复
func certCount(): Int32 {
    var count: Int32 = 0; var cur = rootCert
            while (true) { match (cur) { case Some(c) => count += 1; cur = c.next; case None => break } }
    return count
}

func padRight(s: String, width: Int32): String {
    let runes = s.toRuneArray()
    if (Int32(runes.size) >= width) { return s }
    var result = s
    for (_ in Int32(runes.size)..width) { result += " " }
    return result
}
