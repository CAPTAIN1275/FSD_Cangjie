// clinterface.cj — FSD 客户端接口（Squawkbox/Pro Controller 协议）
// 参考 C 原版: cluser.cpp / clinterface.cpp
// 修复：字段顺序对齐原版协议

package FSD_Cangjie

import std.net.*
import std.fs.*
import std.collection.*

public class ClInterface <: NetInterface {
    var allowList: ArrayList<String>
    public init(port: Int32, name: String, description: String) {
        super(port, name, description); this.allowList = ArrayList<String>()
    }
    public override func createUser(socket: TcpSocket): NetUser {
        let u = ClUser(socket, this)
        this.users.add(u)
        return u
    }

    public func sendError(user: ClUser, code: Int32, env: String, callsign: String): Unit {
        let paddedCode = if (code < 10) { "00${code}" } else if (code < 100) { "0${code}" } else { "${code}" }
        user.outStr += "\$ERserver:${callsign}:${paddedCode}:${env}:${errStr(code)}\r\n"
    }

    // ---- #AA / #AP 登录（字段顺序对齐原版协议）----
    // #AA 格式: #AAcallsign:SERVER:realname:cid:password:rating:protocol
    // #AP 格式: #APcallsign:SERVER:cid:password:rating:protocol:simtype:realname
    public func handleAddClient(user: ClUser, line: String): Unit {
        let prefix = if (line.startsWith("#AA")) { "#AA" } else { "#AP" }
        let data = substrFrom(line, Int64(prefix.toRuneArray().size))
        let parts = splitStr(data, ":")
        if (parts.size < 2) { sendError(user, ERR_SYNTAX, "unknown", "unknown"); return }

        let callsign = parts[0]
        if (parts.size < 7) { sendError(user, ERR_SYNTAX, callsign, callsign); return }

        // parts[1] = "SERVER" (literal, skip)
        let isAtc = (prefix == "#AA")

        if (isAtc) {
            // #AA: callsign:SERVER:realname:cid:password:rating:protocol
            if (parts.size < 7) { sendError(user, ERR_SYNTAX, callsign, callsign); return }
            let realname = parts[2]; let cid = parts[3]; let password = parts[4]
            let rating = parseInt32(parts[5]); let protocol = parseInt32(parts[6])
            if (protocol != NEEDREVISION) { sendError(user, ERR_REVISION, "${protocol}", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, callsign, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            let (verified, actualLevel) = verifyUser(cid, password)
            if (!verified) { sendError(user, ERR_CIDINVALID, cid, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (actualLevel <= LEV_SUSPENDED) { sendError(user, ERR_CSSUSPEND, cid, "unknown"); return }
            let client = Client(callsign, cid, realname, password, CLIENT_ATC, actualLevel, protocol)
            client.location = myServer; addClient(client); user.client = client
            dolog(L_INFO, "ATC login: ${callsign} level=${actualLevel}")
            // 发送在线客户端列表给新客户端
            sendAllClientsTo(user)
        } else {
            // #AP: callsign:SERVER:cid:password:rating:protocol:simtype:realname
            if (parts.size < 8) { sendError(user, ERR_SYNTAX, callsign, callsign); return }
            let cid = parts[2]; let password = parts[3]
            let rating = parseInt32(parts[4]); let protocol = parseInt32(parts[5])
            let simtype = parseInt32(parts[6]); let realname = parts[7]
            if (protocol != NEEDREVISION) { sendError(user, ERR_REVISION, "${protocol}", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, callsign, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            let (verified, actualLevel) = verifyUser(cid, password)
            if (!verified) { sendError(user, ERR_CIDINVALID, cid, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (actualLevel <= LEV_SUSPENDED) { sendError(user, ERR_CSSUSPEND, cid, "unknown"); return }
            let client = Client(callsign, cid, realname, password, CLIENT_PILOT, actualLevel, protocol)
            client.location = myServer; client.simtype = simtype
            addClient(client); user.client = client
            dolog(L_INFO, "Pilot login: ${callsign} level=${actualLevel}")
            // 发送在线客户端列表给新客户端
            sendAllClientsTo(user)
        }

        // 广播新客户端给所有人（含自身）
        if (let Some(cl) <- user.client) {
            broadcastToClients(buildAddClientLine(cl), cl.callsign)
            serverInterface?.sendAddClient("*", cl, None)
        }
        sendMotd(user, callsign)
    }

    public func sendMotd(user: ClUser, callsign: String): Unit {
        // 原版格式：#TMserver:callsign:message
        user.outStr += "#TMserver:${callsign}:${PRODUCT}\r\n"
        user.outStr += "#TMserver:${callsign}:Welcome to FSD Cangjie\r\n"
        // 读取 motd.txt
        try {
            let bytes = File.readFrom(Path("motd.txt"))
            let content = String.fromUtf8(bytes)
            for (rawLine in splitStr(content, "\n")) {
                var line = rawLine
                let rs = line.toRuneArray()
                if (rs.size > 0 && rs[Int64(rs.size) - 1] == r'\r') {
                    line = substr(line, 0, Int64(rs.size) - 1)
                }
                if (line != "") { user.outStr += "#TMserver:${callsign}:${line}\r\n" }
            }
        } catch (e: Exception) {}
    }

    // ---- #TM 文字消息 ----
    public func handleTextMessage(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let msg = substrFrom(line, 3)
                let parts = splitStr(msg, ":")
                if (parts.size >= 3) {
                    // 消息可能含冒号，拼接 parts[2] 到末尾
                    var actualMsg = parts[2]
                    for (i in 3..parts.size) { actualMsg += ":${parts[i]}" }
                    routeMessage(parts[0], parts[1], actualMsg)
                }
            case None => sendError(user, ERR_REGISTERED, "Not logged in", "unknown")
        }
    }

    // ---- $FP 飞行计划 ----
    public func handleFlightPlan(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3)
                let idx = data.indexOf(r':')
                match (idx) {
                    case Some(pos) =>
                        let callsign = substrTo(data, pos); let rawData = substrFrom(data, pos + 1)
                        // 跳过 SERVER:type 两段（原版 array+2）
                        let idx2 = rawData.indexOf(r':')
                        match (idx2) {
                            case Some(pos2) =>
                                let afterServer = substrFrom(rawData, pos2 + 1)
                                let idx3 = afterServer.indexOf(r':')
                                match (idx3) {
                                    case Some(pos3) =>
                                        let fpData = substrFrom(afterServer, pos3 + 1)
                                        let fp = FlightPlan.parse(fpData); fp.callsign = callsign; fp.cid = c.cid; c.plan = fp
                                        match (gMysql) { case Some(db) => db.saveFlightPlan(callsign, c.cid, fpData); case None => () }
                                        broadcastToClients("\$FP${callsign}:${fpData}\r\n", None)
                                        serverInterface?.sendPlan("*", c, None)
                                    case None => ()
                                }
                            case None => ()
                        }
                    case None => ()
                }
            case None => sendError(user, ERR_REGISTERED, "Not logged in", "unknown")
        }
    }

    // ---- @ 飞行员位置 / % ATC位置 ----
    public func handlePosition(user: ClUser, line: String): Unit {
        match (user.client) { case Some(c) =>
            c.touch()
            let data = substrFrom(line, 1)
            let parts = splitStr(data, ":")
            if (c.isAtc()) {
                // % 格式: %callsign:frequency:facilitytype:visualrange:rating:lat:lon:altitude
                if (parts.size >= 8) {
                    c.frequency = parseInt32(parts[1]); c.facilitytype = parseInt32(parts[2])
                    c.visualrange = parseInt32(parts[3]); c.rating = parseInt32(parts[4])
                    c.lat = parseFloat(parts[5]); c.lon = parseFloat(parts[6])
                    c.altitude = parseInt32(parts[7])
                }
            } else {
                // @ 格式: @callsign:transponder:rating:lat:lon:altitude:groundspeed:pitch:bank:heading
                if (parts.size >= 9) {
                    c.transponder = parseInt32(parts[1]); c.rating = parseInt32(parts[2])
                    c.lat = parseFloat(parts[3]); c.lon = parseFloat(parts[4])
                    c.altitude = parseInt32(parts[5]); c.groundspeed = parseInt32(parts[6])
                    c.pbh = UInt32(parseInt32(parts[9]))
                }
            }
            broadcastToClients(line + "\r\n", c.callsign)
        ; case None => () }
    }

    // ---- $CQ 查询 / $CR 响应 ----
    public func handleCq(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3); let parts = splitStr(data, ":")
                if (parts.size < 3) { return }
                if (parts[1] == "RN") {
                    match (getClient(parts[0])) {
                        case Some(target) => user.outStr += "\$CR${c.callsign}:${target.callsign}:RN:${target.realname}:USER:${target.rating}\r\n"
                        case None => ()
                    }
                }
            case None => sendError(user, ERR_REGISTERED, "Not logged in", "unknown")
        }
    }

    // ---- #WX 天气 ----
    public func handleWeather(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let parts = splitStr(substrFrom(line, 3), ":")
                if (parts.size >= 3) { match (metarManager) { case Some(mm) => mm.requestMetar("%${c.callsign}", parts[2], 1, 0); case None => () } }
            case None => ()
        }
    }

    // ---- $!! 踢出 ----
    public func handleKill(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                if (c.rating < LEV_SUP_ADMIN) { user.outStr += "#TMserver:${c.callsign}:Permission denied\r\n"; return }
                let parts = splitStr(substrFrom(line, 3), ":")
                if (parts.size >= 2) { match (getClient(parts[0])) { case Some(t) => serverInterface?.sendKill(t.callsign, parts[1]); sendKillClient(t, parts[1]); case None => () } }
            case None => ()
        }
    }

    // ---- 广播 ----
    public func broadcastToClients(data: String, exclude: ?String): Unit {
        for (u in this.users) {
            match (u) { case cu: ClUser => 
                if (let Some(c) <- cu.client) {
                    match (exclude) { case Some(cs) => if (c.callsign == cs) { continue }; case None => () }
                    sendTo(cu, data)
                }
            ; case _ => () }
        }
    }

    public func sendAllClientsTo(user: ClUser): Unit {
        var cl = rootClient
        while (true) { match (cl) {
            case Some(c) =>
                match (user.client) {
                    case Some(myC) =>
                        if (c.callsign != myC.callsign) {
                            user.outStr += buildAddClientLine(c)
                        }
                    case None => ()
                }
                cl = c.next
            case None => break
        }}
    }

    public func routeMessage(from: String, target: String, msg: String): Unit {
        let line = "#TM${from}:${target}:${msg}\r\n"
        for (u in this.users) {
            match (u) { case cu: ClUser => match (cu.client) {
                case Some(c) =>
                    var deliver = false
                    if (target == "*") { deliver = c.callsign != from }
                    else if (target == "*A") { deliver = c.isAtc() && c.callsign != from }
                    else if (target == "*P") { deliver = c.isPilot() && c.callsign != from }
                    else if (target.startsWith("@")) { deliver = c.callsign != from }
                    else { deliver = (c.callsign == target) }
                    if (deliver) { sendTo(cu, line) }
                case None => ()
            }; case _ => () }
        }
    }

    public func sendAddA(client: Client): Unit {
        // 原版格式：#AAcallsign:SERVER:realname:cid::rating:protocol
        broadcastToClients("#AA${client.callsign}:SERVER:${client.realname}:${client.cid}::${client.rating}:${client.protocol}\r\n", None)
    }
    public func sendAddP(client: Client): Unit {
        // 原版格式：#APcallsign:SERVER:cid::rating:protocol:simtype
        broadcastToClients("#AP${client.callsign}:SERVER:${client.cid}::${client.rating}:${client.protocol}:${client.simtype}\r\n", None)
    }
    public func sendRemoveClient(client: Client): Unit {
        let prefix = if (client.isAtc()) { "#DA" } else { "#DP" }
        broadcastToClients("${prefix}${client.callsign}:${client.cid}\r\n", None)
    }
    public func sendKillClient(client: Client, reason: String): Unit {
        broadcastToClients("\$!!SERVER:${client.callsign}:${reason}\r\n", None)
        for (u in this.users) { match (u) { case cu: ClUser => if (let Some(c) <- cu.client) { if (c.callsign == client.callsign) { cu.socket.close() } }; case _ => () } }
    }

    // ---- PD/AD 广播（供 ServInterface 调用）----
    public func broadcastPos(client: Client): Unit {
        broadcastToClients("@${client.transponder}:${client.callsign}:${client.transponder}:${client.rating}:${client.lat}:${client.lon}:${client.altitude}:${client.groundspeed}:${client.pbh}:0\r\n", None)
    }
    public func broadcastAtcPos(client: Client): Unit {
        broadcastToClients("%${client.callsign}:${client.frequency}:${client.facilitytype}:${client.visualrange}:${client.rating}:${client.lat}:${client.lon}:${client.altitude}\r\n", None)
    }
    public func broadcastPlan(client: Client): Unit {
        match (client.plan) { case Some(fp) => broadcastToClients("\$FP${client.callsign}:${fp.serialize()}\r\n", None); case None => () }
    }
    public func broadcastToAll(data: String): Unit {
        for (u in this.users) { u.outStr += data }
    }

    private func buildAddClientLine(c: Client): String {
        if (c.isAtc()) { return "#AA${c.callsign}:SERVER:${c.realname}:${c.cid}::${c.rating}:${c.protocol}\r\n" }
        else { return "#AP${c.callsign}:SERVER:${c.cid}::${c.rating}:${c.protocol}:${c.simtype}\r\n" }
    }

    private func verifyUser(cid: String, pwd: String): (Bool, Int32) {
        match (getCert(cid)) {
            case Some(c) =>
                if (c.password == pwd) {
                    if (c.level <= LEV_SUSPENDED) { return (false, LEV_SUSPENDED) }
                    return (true, c.level)
                }
                return (false, LEV_OBSPILOT)
            case None => ()
        }
        match (gMysql) {
            case Some(db) => return db.verifyCertificate(cid, pwd)
            case None => ()
        }
        return (false, LEV_OBSPILOT)
    }
}

// ============================================================
public class ClUser <: NetUser {
    var client: ?Client = None; var iface: ClInterface
    public init(socket: TcpSocket, iface: ClInterface) { super(socket); this.iface = iface }
    public override func onConnect(): Unit {}
    public override func onDisconnect(): Unit {
        match (this.client) {
            case Some(c) => serverInterface?.sendRmClient("*", c.callsign, None); removeClient(c); this.iface.sendRemoveClient(c)
            case None => ()
        }
        if (this.delayClose) {
            var n: Int64 = 0; for (i in 0..100000000) { n += 1 }
        }
        this.socket.close()
    }
    public override func handleLine(line: String): Unit {
        let trimmed = line.trim()
        if (trimmed == "") { return }
        if (trimmed.startsWith("#AA") || trimmed.startsWith("#AP")) { this.iface.handleAddClient(this, trimmed) }
        else if (trimmed.startsWith("#TM")) { this.iface.handleTextMessage(this, trimmed) }
        else if (trimmed.startsWith("\$FP")) { this.iface.handleFlightPlan(this, trimmed) }
        else if (trimmed.startsWith("@") || trimmed.startsWith("%")) { this.iface.handlePosition(this, trimmed) }
        else if (trimmed.startsWith("\$CQ")) { this.iface.handleCq(this, trimmed) }
        else if (trimmed.startsWith("#WX")) { this.iface.handleWeather(this, trimmed) }
        else if (trimmed.startsWith("\$!!")) { this.iface.handleKill(this, trimmed) }
        else if (trimmed.startsWith("#DA") || trimmed.startsWith("#DP")) {
            if (let Some(c) <- this.client) {
                this.iface.sendRemoveClient(c)
                serverInterface?.sendRmClient("*", c.callsign, None)
                removeClient(c)
            }
            this.client = None
            this.socket.close()
        }
    }
}
