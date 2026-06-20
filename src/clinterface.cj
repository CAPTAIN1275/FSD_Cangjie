// clinterface.cj — FSD 客户端接口（Squawkbox/Pro Controller 协议）
// 参考 C 原版: cluser.cpp / clinterface.cpp
// 修复：字段顺序对齐原版协议

package FSD_Cangjie

import std.net.*
import std.fs.*
import std.collection.*
import std.time.*

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
            if (actualLevel < 2) { sendError(user, ERR_LEVEL, cid, "ATC requires level >= 2"); user.shouldClose = true; user.delayClose = true; return }
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
            let csLen = Int64(callsign.toRuneArray().size)
            let isObserver = (csLen > 4 && substrFrom(callsign, csLen - 4) == "_OBS")
            if (protocol != NEEDREVISION) { sendError(user, ERR_REVISION, "${protocol}", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (isObserver) {
                // 限制每个呼号只能有一个OBS
                if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, callsign, "OBS already connected"); user.shouldClose = true; user.delayClose = true; return }
            } else {
                if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, callsign, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            }
            let (verified, actualLevel) = verifyUser(cid, password)
            if (!verified) { sendError(user, ERR_CIDINVALID, cid, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (actualLevel <= LEV_SUSPENDED) { sendError(user, ERR_CSSUSPEND, cid, "unknown"); return }
            let client = Client(callsign, cid, realname, password, CLIENT_PILOT, actualLevel, protocol)
            client.location = myServer; client.simtype = simtype
            addClient(client); user.client = client
            dolog(L_INFO, "${if (isObserver) { "Observer" } else { "Pilot" }} login: ${callsign} level=${actualLevel}")
            sendAllClientsTo(user)
        }

        // 广播新客户端给所有人
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

    // ---- #TM 原始字节处理（支持 GBK/非 UTF-8 编码） ----
    // ---- #SB 原始字节处理（支持 Opus 语音数据） ----
    public func handleRawTextMessage(user: ClUser, bytes: ArrayList<UInt8>): Unit {
        if (bytes.size < 6) { return }
        // 检查是否 #TM 或 #SB
        let isTM = (bytes[0] == UInt8(35) && bytes[1] == UInt8(84) && bytes[2] == UInt8(77))
        let isSB = (bytes[0] == UInt8(35) && bytes[1] == UInt8(83) && bytes[2] == UInt8(66))
        if (!isTM && !isSB) { return }
        match (user.client) {
            case Some(c) =>
                routeRawMessage(bytes, c.callsign)
            case None => ()
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
                                        broadcastToClients("\$FP${callsign}:SERVER:${fp.`type`}:${fp.serialize()}\r\n", None)
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
                // @ 格式: @identflag:callsign:transponder:rating:lat:lon:altitude:groundspeed:pbh[:flags]
                // parts[0]=identflag, parts[1]=callsign
                try {
                    if (parts.size >= 9) {
                        c.transponder = parseInt32(parts[2]); c.rating = parseInt32(parts[3])
                        c.lat = parseFloat(parts[4]); c.lon = parseFloat(parts[5])
                        c.altitude = parseInt32(parts[6]); c.groundspeed = parseInt32(parts[7])
                        if (parts.size > 8) { c.pbh = UInt32(parseInt32(parts[8])) }
                    }
                } catch (e: Exception) {
                    dolog(L_DEBUG, "POS PARSE: ${e}")
                }
            }
            // 过滤零坐标（客户端刚连上的默认位置），避免非洲西海岸闪现
            if (c.lat > -1.0 && c.lat < 1.0 && c.lon > -1.0 && c.lon < 1.0) { return }
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

    // ---- $HO 管制移交（Handoff）----
    public func handleHandoff(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                // $HOcallsign:frequency:controller
                if (line.size > 3) {
                    broadcastToClients(line + "\r\n", c.callsign)
                }
            case None => ()
        }
    }

    // ---- $!! 管理员命令 ----
    public func handleKill(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                if (c.rating < LEV_SUP_ADMIN) { user.outStr += "#TMserver:${c.callsign}:Permission denied\r\n"; return }
                let parts = splitStr(substrFrom(line, 3), ":")
                if (parts.size < 1) { return }
                let cmd = parts[0]
                if (cmd == "WALLOP") {
                    if (parts.size < 2) { return }
                    var msg = ""; for (i in 1..parts.size) { if (msg != "") { msg += ":" }; msg += parts[i] }
                    broadcastToClients("#TMserver:*:${msg}\r\n", None)
                } else if (cmd == "SUP") {
                    if (parts.size < 2) { return }
                    match (getClient(parts[1])) {
                        case Some(t) => t.rating = LEV_SUP_ADMIN; user.outStr += "#TMserver:${c.callsign}:${parts[1]} 已提升为 SUPERVISOR\r\n"
                        case None => user.outStr += "#TMserver:${c.callsign}:找不到客户端 ${parts[1]}\r\n"
                    }
                } else if (cmd == "ADMIN") {
                    if (c.rating < LEV_ADMIN) { user.outStr += "#TMserver:${c.callsign}:需要 ADMIN 权限\r\n"; return }
                    if (parts.size < 2) { return }
                    match (getClient(parts[1])) {
                        case Some(t) => t.rating = LEV_ADMIN; user.outStr += "#TMserver:${c.callsign}:${parts[1]} 已提升为 ADMIN\r\n"
                        case None => user.outStr += "#TMserver:${c.callsign}:找不到客户端 ${parts[1]}\r\n"
                    }
                } else if (cmd == "ALLOW") {
                    if (parts.size < 2) { return }
                    let minRating = parseInt32(parts[1])
                    // 存储最小允许等级（在全局变量或配置中）
                    user.outStr += "#TMserver:${c.callsign}:最低连接等级已设为 ${minRating}\r\n"
                } else if (cmd == "DENY") {
                    if (parts.size < 2) { return }
                    match (getClient(parts[1])) {
                        case Some(t) => serverInterface?.sendKill(t.callsign, "Denied by admin"); sendKillClient(t, "Denied by admin"); user.outStr += "#TMserver:${c.callsign}:已拒绝 ${parts[1]}\r\n"
                        case None => user.outStr += "#TMserver:${c.callsign}:找不到客户端 ${parts[1]}\r\n"
                    }
                } else if (cmd == "GUARD") {
                    user.outStr += "#TMserver:${c.callsign}:Guard 功能未实现\r\n"
                } else if (cmd == "STATS") {
                    match (user.client) {
                        case Some(me) =>
                            let now = mgmtime()
                            let durationMin = (now - me.startTime) / 60
                            let durationStr = if (durationMin >= 60) { "${durationMin / 60}小时${durationMin % 60}分钟" } else { "${durationMin}分钟" }
                            user.outStr += "#TMserver:${c.callsign}:--- 连线统计 ---\r\n"
                            user.outStr += "#TMserver:${c.callsign}:呼号: ${me.callsign} (CID:${me.cid})\r\n"
                            user.outStr += "#TMserver:${c.callsign}:本次连线时长: ${durationStr}\r\n"
                            // 统计历史总时长
                            var totalMin: Int64 = 0
                            try {
                                let content = String.fromUtf8(File.readFrom(Path("stats.txt")))
                                for (l in splitStr(content, "\n")) {
                                    let fields = splitStr(l, ":")
                                    if (fields.size >= 5 && fields[0] == me.cid) {
                                        totalMin += Int64(parseInt32(fields[4]))
                                    }
                                }
                            } catch (e: Exception) {}
                            if (totalMin > 0) {
                                let totalStr = if (totalMin >= 60) { "${totalMin / 60}小时${totalMin % 60}分钟" } else { "${totalMin}分钟" }
                                user.outStr += "#TMserver:${c.callsign}:历史总计: ${totalStr}\r\n"
                            }
                            // 在线用户数（排除 OBS）
                            var pilotCount = 0; var atcCount = 0; var obsCount = 0
                            var cur = rootClient
                            while (true) { match (cur) { case Some(cl) =>
                                let csLen = Int64(cl.callsign.toRuneArray().size)
                                let isObs = (csLen > 4 && substrFrom(cl.callsign, csLen - 4) == "_OBS")
                                if (isObs) { obsCount += 1 }
                                else if (cl.isAtc()) { atcCount += 1 }
                                else { pilotCount += 1 }
                                cur = cl.next
                            ; case None => break }}
                            user.outStr += "#TMserver:${c.callsign}:在线: ${pilotCount} 机组 / ${atcCount} 管制 / ${obsCount} OBS\r\n"
                        case None => ()
                    }
                } else {
                    // 原 kill 逻辑
                    if (parts.size >= 2) { match (getClient(parts[0])) { case Some(t) => serverInterface?.sendKill(t.callsign, parts[1]); sendKillClient(t, parts[1]); case None => () } }
                }
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
                            // 同步飞行计划
                            match (c.plan) { case Some(fp) => user.outStr += "\$FP${c.callsign}:SERVER:${fp.`type`}:${fp.serialize()}\r\n"; case None => () }
                            // 同步ATC频率/位置（即使频率为0也发，客户端自行解析）
                            if (c.isAtc()) {
                                user.outStr += "%${c.callsign}:${c.frequency}:${c.facilitytype}:${c.visualrange}:${c.rating}:${c.lat}:${c.lon}:${c.altitude}\r\n"
                            }
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

    // ---- #TM/#SB 原始字节路由（非 UTF-8 编码透传，支持语音） ----
    public func routeRawMessage(bytes: ArrayList<UInt8>, fromCallsign: String): Unit {
        // 找到两个 : 分隔符
        var sep1: Int64 = -1; var sep2: Int64 = -1
        for (i in 3..bytes.size) {
            if (bytes[i] == UInt8(58)) {  // ':'
                if (sep1 < 0) { sep1 = i }
                else { sep2 = i; break }
            }
        }
        if (sep1 < 0 || sep2 < 0) { return }
        // 提取 target (sep1+1..sep2)
        let targetStart = sep1 + 1; let targetEnd = sep2
        // 构建输出字节: prefix + from + : + target + : + body + \r\n
        var out = ArrayList<UInt8>()
        out.add(bytes[0]); out.add(bytes[1]); out.add(bytes[2])  // #TM 或 #SB
        for (i in 3..sep1) { out.add(bytes[i]) }  // from
        out.add(UInt8(58))  // :
        for (i in targetStart..targetEnd) { out.add(bytes[i]) }  // target
        out.add(UInt8(58))  // :
        for (i in (sep2 + 1)..bytes.size) { out.add(bytes[i]) }  // body
        out.add(UInt8(13)); out.add(UInt8(10))  // \r\n
        let outArr = out.toArray()

        // 目标以 @ 开头 = 频率广播，转发给同频率的客户端
        var isFreqBcast = false
        if (targetEnd > targetStart && bytes[targetStart] == UInt8(64)) {  // '@'
            isFreqBcast = true
        }

        // 分发到所有匹配的客户端
        for (u in this.users) {
            match (u) { case cu: ClUser => match (cu.client) {
                case Some(c) =>
                    if (c.callsign == fromCallsign) { continue }
                    var deliver = false
                    if (isFreqBcast) {
                        deliver = true  // 频率广播全部转发（简化处理）
                    } else {
                        // 提取目标呼号
                        var targetBuf = ArrayList<UInt8>()
                        for (i in targetStart..targetEnd) { targetBuf.add(bytes[i]) }
                        let targetCs = String.fromUtf8(targetBuf.toArray())
                        deliver = (c.callsign == targetCs)
                    }
                    if (deliver) {
                        try { cu.socket.write(outArr) } catch (_: Exception) {}
                    }
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
        match (client.plan) { case Some(fp) => broadcastToClients("\$FP${client.callsign}:SERVER:${fp.`type`}:${fp.serialize()}\r\n", None); case None => () }
    }
    public func broadcastToAll(data: String): Unit {
        for (u in this.users) { u.outStr += data }
    }

    private func buildAddClientLine(c: Client): String {
        if (c.isAtc()) { return "#AA${c.callsign}:SERVER:${c.realname}:${c.cid}::${c.rating}:${c.protocol}\r\n" }
        else { return "#AP${c.callsign}:SERVER:${c.cid}::${c.rating}:${c.protocol}:${c.simtype}\r\n" }
    }

    private func verifyUser(cid: String, pwd: String): (Bool, Int32) {
        match (gMysql) {
            case Some(db) =>
                if (db.isConnected()) {
                    // MySQL 已配置并连接 → 只用 MySQL，不回退 cert.txt
                    let (verified, level) = db.verifyCertificate(cid, pwd)
                    dolog(L_DEBUG, "MySQL auth: ${cid} verified=${verified} level=${level}")
                    return (verified, level)
                }
            case None => ()
        }
        // 无 MySQL 时回退 cert.txt
        match (getCert(cid)) {
            case Some(c) =>
                if (c.password == pwd) {
                    if (c.level <= LEV_SUSPENDED) { return (false, LEV_SUSPENDED) }
                    return (true, c.level)
                }
                return (false, LEV_OBSPILOT)
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
            case Some(c) =>
                let durationMin = (mgmtime() - c.startTime) / 60
                let ctype = if (c.isAtc()) { "ATC" } else { "PILOT" }
                dolog(L_INFO, "CLIENT DISCONNECT: ${c.callsign} (CID:${c.cid}) type=${ctype} duration=${durationMin}min")
                // 保存到统计文件（OBS 不计入）
                let csLen = Int64(c.callsign.toRuneArray().size)
                let isObs = (csLen > 4 && substrFrom(c.callsign, csLen - 4) == "_OBS")
                if (!isObs && durationMin > 0) {
                    try {
                        let line = "${c.cid}:${c.callsign}:${mgmtime()}:${ctype}:${durationMin}\n"
                        var content = line
                        try { content = String.fromUtf8(File.readFrom(Path("stats.txt"))) + line } catch (e: Exception) {}
                        File.writeTo(Path("stats.txt"), content.toArray())
                        dolog(L_INFO, "Stats saved: ${c.callsign} ${durationMin}min")
                    } catch (e: Exception) {
                        dolog(L_ERR, "Stats write error: ${e}")
                    }
                }
                serverInterface?.sendRmClient("*", c.callsign, None); removeClient(c); this.iface.sendRemoveClient(c); fsdEngine?.writeWhazzUp()
            case None => ()
        }
        if (this.delayClose) {
            var n: Int64 = 0; for (i in 0..100000000) { n += 1 }
        }
        this.socket.close()
        // 从用户列表移除自己，防止内存泄漏
        var found: ?Int64 = None
        for (idx in 0..this.iface.users.size) {
            match (this.iface.users[Int64(idx)]) {
                case cu: ClUser =>
                    match (cu.client) {
                        case Some(c) =>
                            match (this.client) {
                                case Some(myc) => if (c.callsign == myc.callsign) { found = Int64(idx); break }
                                case None => ()
                            }
                        case None => ()
                    }
                case _ => ()
            }
        }
        match (found) {
            case Some(idx) => this.iface.users.remove(idx..(idx+1))
            case None => ()
        }
    }
    public override func handleLine(line: String): Unit {
        let trimmed = line.trim()
        if (trimmed == "") { return }
        if (trimmed.startsWith("#AA") || trimmed.startsWith("#AP")) { this.iface.handleAddClient(this, trimmed) }
        // #TM 由 handleRawLine 处理（原始字节透传），String 路径跳过
        else if (trimmed.startsWith("\$FP")) { this.iface.handleFlightPlan(this, trimmed) }
        else if (trimmed.startsWith("@") || trimmed.startsWith("%")) { this.iface.handlePosition(this, trimmed) }
        else if (trimmed.startsWith("\$CQ")) { this.iface.handleCq(this, trimmed) }
        else if (trimmed.startsWith("#WX")) { this.iface.handleWeather(this, trimmed) }
        else if (trimmed.startsWith("\$HO")) { this.iface.handleHandoff(this, trimmed) }
        else if (trimmed.startsWith("\$!!")) { this.iface.handleKill(this, trimmed) }
        else if (trimmed.startsWith("#DA") || trimmed.startsWith("#DP")) {
            if (let Some(c) <- this.client) {
                // 保存统计（在清空 client 之前）
                let durationMin = (mgmtime() - c.startTime) / 60
                let ctype = if (c.isAtc()) { "ATC" } else { "PILOT" }
                dolog(L_INFO, "CLIENT DISCONNECT: ${c.callsign} (CID:${c.cid}) type=${ctype} duration=${durationMin}min")
                let csLen = Int64(c.callsign.toRuneArray().size)
                let isObs = (csLen > 4 && substrFrom(c.callsign, csLen - 4) == "_OBS")
                if (!isObs && durationMin > 0) {
                    try {
                        let line = "${c.cid}:${c.callsign}:${mgmtime()}:${ctype}:${durationMin}\n"
                        var content = line
                        try { content = String.fromUtf8(File.readFrom(Path("stats.txt"))) + line } catch (e: Exception) {}
                        File.writeTo(Path("stats.txt"), content.toArray())
                        dolog(L_INFO, "Stats saved: ${c.callsign} ${durationMin}min")
                    } catch (e: Exception) {
                        dolog(L_ERR, "Stats write error: ${e}")
                    }
                }
                this.iface.sendRemoveClient(c)
                serverInterface?.sendRmClient("*", c.callsign, None)
                removeClient(c)
                fsdEngine?.writeWhazzUp()
            }
            this.client = None
            this.socket.close()
        }
    }
    // 原始字节处理（非 UTF-8 编码，如 GBK 中文）
    public override func handleRawLine(bytes: ArrayList<UInt8>): Unit {
        this.iface.handleRawTextMessage(this, bytes)
    }
}
