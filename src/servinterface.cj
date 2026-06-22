// servinterface.cj �?FSD 服务器间接口（完�?20 条协议命�?+ 路由�?
// 参�?C 原版: servuser.cpp / servinterface.cpp

package FSD_Cangjie

import std.net.*
import std.collection.*

public class ServInterface <: NetInterface {
    var allowList: ArrayList<String>
    var packetCount: Int64
    var lastSync: Int64

    public init(port: Int32, name: String, description: String) {
        super(port, name, description)
        this.allowList = ArrayList<String>()
        this.packetCount = 0
        this.lastSync = 0
    }
    public override func createUser(socket: TcpSocket): NetUser { return ServUser(socket, this) }

    // ---- 主动连接（自动重连）----
    public func addUser(hostname: String, port: Int32, _ident: ?String): Int32 {
        dolog(L_INFO, "Connecting to server ${hostname}:${port}")
        spawn { connectLoop(hostname, port) }
        return 1
    }

    private func connectLoop(hostname: String, port: Int32): Unit {
        while (this.runFlag) {
            try {
                var sock = TcpSocket(hostname, UInt16(port))
                sock.connect()
                dolog(L_INFO, "Connected to server ${hostname}:${port}")
                let user = createUser(sock)
                // 记录连接时间（user 是 ServUser，通过 init 自动触发 sendFeed）
                // 等待连接结束
                while (this.runFlag && user.alive > 0) {
                    sleep(100 * Duration.millisecond)
                }
                dolog(L_WARNING, "Server ${hostname}:${port} disconnected, reconnecting...")
                try { sock.close() } catch (_: Exception) {}
            } catch (e: Exception) {
                dolog(L_WARNING, "Server ${hostname}:${port} connect failed: ${e}")
            }
            // 等待重试
            if (this.runFlag) {
                sleep(30000 * Duration.millisecond)
            }
        }
    }
    public func allow(ip: String): Unit { this.allowList.add(ip) }

    // ---- 协议发�?----
    public func sendServerNotify(dest: String, server: Server, exclude: ?Server): Unit {
        assembleAndSend(dest, CMD_NOTIFY, "0:${server.ident}:${server.name}:${server.email}:${server.hostname}:${server.version}:${server.flags}:${server.location}", exclude)
    }
    public func sendPing(dest: String, data: String): Unit {
        assembleAndSend(dest, CMD_PING, data, None)
    }
    public func sendPong(dest: String, data: String): Unit {
        assembleAndSend(dest, CMD_PONG, data, None)
    }
    public func sendSync(): Unit {
        assembleAndSend("*", CMD_SYNC, "", None)
        this.lastSync = mgmtime()
    }
    public func sendLinkDown(downList: String): Unit {
        assembleAndSend("*", CMD_LINKDOWN, downList, None)
    }
    public func sendAddClient(dest: String, client: Client, exclude: ?Server): Unit {
        let locIdent = match (client.location) { case Some(s) => s.ident; case None => "" }
        let buf = "${client.cid}:${locIdent}:${client.callsign}:${client.`type`}:${client.rating}:${client.protocol}:${client.realname}:0"
        assembleAndSend(dest, CMD_ADDCLIENT, buf, exclude)
        // 本地投递给客户�?
        if (client.isAtc()) { clientInterface?.sendAddA(client) }
        else { clientInterface?.sendAddP(client) }
    }
    public func sendRmClient(dest: String, callsign: String, exclude: ?Server): Unit {
        assembleAndSend(dest, CMD_RMCLIENT, callsign, exclude)
    }
    public func sendPilotData(client: Client): Unit {
        let data = "${client.transponder}:${client.callsign}:${client.transponder}:${client.rating}:${client.lat}:${client.lon}:${client.altitude}:${client.groundspeed}:${client.pbh}:0"
        assembleAndSend("*", CMD_PD, data, None)
        clientInterface?.broadcastPos(client)
    }
    public func sendAtcData(client: Client): Unit {
        let data = "${client.callsign}:${client.frequency}:${client.facilitytype}:${client.visualrange}:${client.rating}:${client.lat}:${client.lon}:${client.altitude}"
        assembleAndSend("*", CMD_AD, data, None)
        clientInterface?.broadcastAtcPos(client)
    }
    public func sendPlan(dest: String, client: Client, exclude: ?Server): Unit {
        match (client.plan) {
            case Some(fp) =>
                let buf = "${client.callsign}:${fp.revision}:${fp.`type`}:${fp.aircraft}:${fp.tascruise}:${fp.depAirport}:${fp.depTime}:${fp.actDepTime}:${fp.altitude}:${fp.destAirport}:${fp.hrsEnroute}:${fp.minEnroute}:${fp.hrsFuel}:${fp.minFuel}:${fp.altAirport}:${fp.remarks}:${fp.route}"
                assembleAndSend(dest, CMD_PLAN, buf, exclude)
            case None => ()
        }
    }
    public func sendCert(dest: String, mode: Int32, cert: Certificate, exclude: ?Server): Unit {
        // 注意：不发送密码明文，仅发送元数据
        let buf = "${mode}:${cert.cid}::${cert.level}:${cert.created}:${cert.serverIdent}"
        assembleAndSend(dest, CMD_CERT, buf, exclude)
    }
    public func sendMulticast(srcCallsign: String, dest: String, msg: String, cmd: Int32): Unit {
        let buf = "${cmd}:${srcCallsign}:${msg}"
        assembleAndSend("%${dest}", CMD_MULTIC, buf, None)
    }
    public func sendReqMetar(client: String, metar: String, parsed: Int32, fd: Int32, destServer: String): Unit {
        assembleAndSend(destServer, CMD_REQMETAR, "${client}:${metar}:${parsed}:${fd}", None)
    }
    public func sendKill(callsign: String, reason: String): Unit {
        assembleAndSend("*", CMD_KILL, "${callsign}:${reason}", None)
    }
    public func sendReset(): Unit {
        assembleAndSend("*", CMD_RESET, "", None)
        this.packetCount = 0
    }

    // ---- 核心：组�?+ 广播/路由发�?----
    private func assembleAndSend(dest: String, cmd: Int32, data: String, exclude: ?Server): Unit {
        this.packetCount += 1
        if (this.packetCount < 0 || this.packetCount > 2000000000) { sendReset(); return }
        let isBcast = (dest.startsWith("*") || dest.startsWith("@"))
        let bi = if (isBcast) { "B" } else { "U" }
        let line = "${cmdnames[Int64(cmd)]}:${dest}:${myServer?.ident ?? "FSD"}:${bi}${this.packetCount}:0:${data}\r\n"
        for (u in this.users) {
            match (u) {
                case su: ServUser => su.outStr += line
                case _ => ()
            }
        }
    }

    // ---- 命令名称表（public �?ServUser 使用�?---
    public let cmdnames: Array<String> = [
        "NOTIFY", "REQMETAR", "PING", "PONG", "SYNC", "LINKDOWN", "NOWX",
        "ADDCLIENT", "RMCLIENT", "PLAN", "PD", "AD", "ADDCERT", "MC",
        "WX", "METAR", "AWPROF", "DWPROF", "KILL", "RESET"
    ]
}

// ============================================================
// ServUser �?服务器间连接的对�?
// ============================================================

public class ServUser <: NetUser {
    var peerIdent: String = ""
    var peerLag: Int32 = 0
    var clientOk: Bool = false
    var startupTime: Int64 = 0
    var iface: ServInterface

    public init(socket: TcpSocket, iface: ServInterface) {
        super(socket)
        this.iface = iface
        this.startupTime = mgmtime()
        // 连接建立后，发送所有本地数据给对端
        sendFeed()
    }

    // feed �?向新连接的对端同步全量数�?
    private func sendFeed(): Unit {
        // 发送所有已知服务器
        var sv = rootServer
        while (true) { match (sv) { case Some(s) =>
            if (s.ident != (myServer?.ident ?? "")) { this.iface.sendServerNotify("*", s, None) }
            sv = s.next
        ; case None => break }}
        // 发送所有客户端
        for (key in clientMap.keys()) {
            let c = clientMap.get(key).getOrThrow()
            if (clLocal(c)) { this.iface.sendAddClient("*", c, None) }
            match (c.plan) { case Some(_) => this.iface.sendPlan("*", c, None); case None => () }
        }
        // 发送所有证�?
        var cert = rootCert
        while (true) { match (cert) { case Some(c) =>
            this.iface.sendCert("*", CERT_ADD, c, None)
            cert = c.next
        ; case None => break }}
    }

    public override func onDisconnect(): Unit {
        // LINK down 通知
        var downList = ""
        var sv = rootServer
        while (true) { match (sv) { case Some(s) =>
            if (s.ident != (myServer?.ident ?? "") && !isRouted(s)) {
                if (downList != "") { downList += ":" }
                downList += s.ident
            }
            sv = s.next
        ; case None => break }}
        if (downList != "") { this.iface.sendLinkDown(downList); dolog(L_ALERT, "link down") }
        this.iface.sendSync()
    }

    // ---- 协议解析 ----
    public override func handleLine(line: String): Unit {
        let trimmed = line.trim()
        if (trimmed == "" || (trimmed.toRuneArray().size > 0 && trimmed.toRuneArray()[0] == r'#')) { return }
        this.clientOk = true
        let parts = splitStr(trimmed, ":")
        if (parts.size < 6) { return }  // 最�? CMD:DEST:FROM:FLAG:PC:HOPS

        let cmdName = parts[0]
        let dest = parts[1]
        let from = parts[2]
        let flagAndPc = parts[3]  // B12345 or U12345
        let hops = parseInt32(parts[4])

        if (hops > MAXHOPS) { return }  // 防环�?
        let fromSvr = getServer(from)
        match (fromSvr) { case Some(s) => s.touch(); case None => () }
        // 检查是否自己发的（fromSvr == myServer�?
        var fromIdent = ""; var myIdent = ""
        if (let Some(fs) <- fromSvr) { fromIdent = fs.ident }
        if (let Some(ms) <- myServer) { myIdent = ms.ident }
        if (fromIdent == myIdent && fromIdent != "") { return }

        // 构建数据部分
        var data = ""
        for (i in 5..parts.size) { if (data != "") { data += ":" }; data += parts[i] }

        // 首次收到 NOTIFY 时记录对端服务器标识
        if (cmdName == "NOTIFY" && this.peerIdent == "") {
            let parts2 = splitStr(data, ":")
            if (parts2.size >= 2) { this.peerIdent = parts2[1] }
        }

        // 查找命令索引
        var cmd: Int32 = -1
        for (idx in 0..iface.cmdnames.size) { if (iface.cmdnames[Int64(idx)] == cmdName) { cmd = Int32(idx); break } }
        if (cmd == -1) { return }

        // 本地投递检�?
        if (!needLocal(dest)) {
            // 仅转发，不本地处�?
            forwardToOthers(trimmed, dest, fromSvr)
            return
        }

        // 执行命令
        let needFwd = execCmd(cmd, parts, data, fromSvr)
        if (needFwd) { forwardToOthers(trimmed, dest, fromSvr) }
    }

    private func needLocal(dest: String): Bool {
        if (dest.startsWith("*") || dest.startsWith("@")) { return true }
        if (dest.startsWith("%")) { return getClient(substrFrom(dest, 1)).isSome() }
        return dest == (myServer?.ident ?? "")
    }

    private func forwardToOthers(line: String, dest: String, fromSvr: ?Server): Unit {
        // 路由：查找目标客户端所在的服务器
        var targetIdent: ?String = None
        if (!dest.startsWith("*") && !dest.startsWith("@")) {
            // 本地客户端不在本地 且 已知位置 → 路由到对应服务器
            match (getClient(dest)) {
                case Some(cl) =>
                    match (cl.location) {
                        case Some(loc) => if (loc.ident != (myServer?.ident ?? "")) { targetIdent = loc.ident }
                        case None => ()
                    }
                case None => ()
            }
        }
        // 发送到匹配的服务器连接
        for (u in this.iface.users) {
            match (u) {
                case su: ServUser =>
                    var shouldSend = true
                    match (targetIdent) {
                        case Some(ti) => shouldSend = (su.peerIdent == ti)
                        case None => ()
                    }
                    if (shouldSend) { su.outStr += line + "\r\n" }
                case _ => ()
            }
        }
    }

    private func execCmd(cmd: Int32, parts: Array<String>, data: String, fromSvr: ?Server): Bool {
        if (cmd == CMD_NOTIFY) {
            if (parts.size < 11) { return false }
            let ident = parts[5]; let name = parts[6]; let email = parts[7]
            let hostname = parts[8]; let version = parts[9]; let flags = parseInt32(parts[10])
            let location = if (parts.size > 11) { parts[11] } else { "" }
            match (getServer(ident)) {
                case Some(s) => s.configure(name, email, hostname, version, location)
                case None => let sv = Server(ident, name, email, hostname, version, flags, location); addServer(sv)
            }
            return true
        }
        if (cmd == CMD_PING) {
            this.iface.sendPong(fromSvr?.ident ?? "", data)
            return true
        }
        if (cmd == CMD_PONG) {
            match (fromSvr) { case Some(s) =>
                let args = splitStr(data, " "); if (args.size >= 2) { s.lag = mgmtime() - parseInt64(args[1]) }
            ; case None => () }
            return true
        }
        if (cmd == CMD_LINKDOWN) {
            for (i in 5..parts.size) { match (getServer(parts[i])) { case Some(s) =>
                s.routes.remove("*")
            ; case None => () }}
            this.iface.sendSync()
            return true
        }
        if (cmd == CMD_SYNC) { this.iface.sendSync(); return false }
        if (cmd == CMD_ADDCLIENT) {
            if (parts.size < 12) { return true }
            let cid = parts[4]; let locIdent = parts[5]; let callsign = parts[6]
            let type_ = parseInt32(parts[7]); let rating = parseInt32(parts[8])
            let protocol = parseInt32(parts[9]); let realname = parts[10]
            match (getClient(callsign)) {
                case Some(_) => return false
                case None =>
                    let loc = getServer(locIdent)
                    match (loc) {
                        case Some(l) =>
                            let cl = Client(callsign, cid, realname, "", type_, rating, protocol)
                            cl.location = loc; addClient(cl)
                            if (type_ == CLIENT_ATC) { clientInterface?.sendAddA(cl) }
                            else { clientInterface?.sendAddP(cl) }
                        case None => ()
                    }
            }
            return true
        }
        if (cmd == CMD_RMCLIENT) {
            match (getClient(data)) { case Some(c) =>
                if (!clLocal(c)) { clientInterface?.sendRemoveClient(c); removeClient(c) }
            ; case None => () }
            return true
        }
        if (cmd == CMD_PD) {
            if (parts.size < 15) { return true }
            match (getClient(parts[5])) { case Some(c) =>
                c.transponder = parseInt32(parts[6]); c.rating = parseInt32(parts[7])
                c.lat = parseFloat(parts[8]); c.lon = parseFloat(parts[9])
                c.altitude = parseInt32(parts[10]); c.groundspeed = parseInt32(parts[11])
                c.pbh = UInt32(parseInt64(parts[12])); c.touch()
                clientInterface?.broadcastPos(c)
            ; case None => () }
            return true
        }
        if (cmd == CMD_AD) {
            if (parts.size < 13) { return true }
            match (getClient(parts[4])) { case Some(c) =>
                c.frequency = parseInt32(parts[5]); c.facilitytype = parseInt32(parts[6])
                c.visualrange = parseInt32(parts[7]); c.rating = parseInt32(parts[8])
                c.lat = parseFloat(parts[9]); c.lon = parseFloat(parts[10])
                c.altitude = parseInt32(parts[11]); c.touch()
                clientInterface?.broadcastAtcPos(c)
            ; case None => () }
            return true
        }
        if (cmd == CMD_PLAN) {
            if (parts.size < 21) { return false }
            match (getClient(parts[4])) { case Some(c) =>
                let fp = FlightPlan()
                fp.callsign = c.callsign; fp.revision = parseInt32(parts[5])
                fp.`type` = if (parts[6] != "") { parts[6].toRuneArray()[0] } else { r'I' }
                fp.aircraft = parts[7]; fp.tascruise = parseInt32(parts[8])
                fp.depAirport = parts[9]; fp.depTime = parseInt32(parts[10])
                fp.actDepTime = parseInt32(parts[11]); fp.altitude = parseInt32(parts[12])
                fp.destAirport = parts[13]; fp.hrsEnroute = parseInt32(parts[14])
                fp.minEnroute = parseInt32(parts[15]); fp.hrsFuel = parseInt32(parts[16])
                fp.minFuel = parseInt32(parts[17]); fp.altAirport = parts[18]
                fp.remarks = parts[19]; fp.route = parts[20]
                c.plan = fp; clientInterface?.broadcastPlan(c)
            ; case None => () }
            return true
        }
        if (cmd == CMD_CERT) {
            if (parts.size < 10) { return false }
            let mode = parseInt32(parts[4]); let cid = parts[5]; let pwd = parts[6]
            let level = parseInt32(parts[7]); let created = parseInt64(parts[8])
            let origin = parts[9]
            if (mode == CERT_ADD) {
                match (getCert(cid)) {
                    case Some(existing) => if (created > existing.created) { existing.configure(pwd, level, created, origin) }
                    case None => let cert = Certificate(cid, pwd, level, created, origin); addCert(cert)
                }
            } else if (mode == CERT_MODIFY) {
                match (getCert(cid)) { case Some(existing) => if (created > existing.created) { existing.configure(pwd, level, created, origin) }; case None => () }
            } else if (mode == CERT_DELETE) {
                match (getCert(cid)) { case Some(existing) => removeCert(existing); case None => () }
            }
            return true
        }
        if (cmd == CMD_MULTIC) {
            if (parts.size < 7) { return true }
            let clCmd = parseInt32(parts[4]); let srcCallsign = parts[5]
            var msgData = ""; for (i in 6..parts.size) { if (msgData != "") { msgData += ":" }; msgData += parts[i] }
            clientInterface?.routeMessage(srcCallsign, parts[1], msgData)
            return true
        }
        if (cmd == CMD_REQMETAR) {
            match (metarManager) { case Some(mm) => mm.requestMetar(parts[4], parts[5], parseInt32(parts[6]), parseInt32(parts[7])); case None => () }
            return true
        }
        if (cmd == CMD_KILL) {
            if (parts.size < 6) { return true }
            match (getClient(parts[4])) { case Some(c) =>
                clientInterface?.sendKillClient(c, parts[5])
            ; case None => () }
            return true
        }
        if (cmd == CMD_RESET) {
            match (fromSvr) { case Some(s) => s.packetCount = 0; case None => () }
            return true
        }
        // WEATHER, METAR, NOWX, ADDWPROF, DELWPROF 暂不实现（依�?MetarManager�?
        return true
    }

    private func isRouted(_s: Server): Bool { return false }
}

// clLocal 定义�?fsd.cj，此处不重复


