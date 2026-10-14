// clinterface.cj — FSD 客户端接口（Squawkbox/Pro Controller 协议）
// 参考 C 原版: cluser.cpp / clinterface.cpp
// 修复：字段顺序对齐原版协议

package FSD_Cangjie

import std.net.*
import std.fs.*
import std.collection.*
import std.time.*
import std.sync.*

var statsLock = Mutex()

// 登录闸门：限制同时在处理的登录数。大规模同时登录时，把 O(N²) 的瞬时分配峰值压平，防 OOM。
let MAX_CONCURRENT_LOGINS: Int64 = 16
var loginGate = Semaphore(MAX_CONCURRENT_LOGINS)

public class ClInterface <: NetInterface {
    var allowList: ArrayList<String>
    public init(port: Int32, name: String, description: String) {
        super(port, name, description); this.allowList = ArrayList<String>()
    }
    public override func createUser(socket: TcpSocket): NetUser {
        let u = ClUser(socket, this)
        synchronized(this.usersLock) { this.users.add(u) }
        return u
    }
    public func allow(ip: String): Unit { this.allowList.add(ip) }
    public func isAllowed(ip: String): Bool {
        if (this.allowList.size == 0) { return true }
        return this.allowList.contains(ip)
    }
    public override func checkPeer(socket: TcpSocket): Bool {
        // IP 白名单：allowList 为空则允许所有；否则只允许列表内 IP
        if (this.allowList.size == 0) { return true }
        return this.allowList.contains(peerIp(socket))
    }

    public func sendError(user: ClUser, code: Int32, env: String, callsign: String): Unit {
        let paddedCode = if (code < 10) { "00${code}" } else if (code < 100) { "0${code}" } else { "${code}" }
        let msg = "\$ERserver:${callsign}:${paddedCode}:${env}:${errStr(code)}\r\n"
        sendTo(user, msg)
    }

    // #AA 格式: #AAcallsign:SERVER:realname:cid:password:rating:protocol
    // #AP 格式: #APcallsign:SERVER:cid:password:rating:protocol:simtype:realname
    public func handleAddClient(user: ClUser, line: String): Unit {
        // 登录闸门：限制并发登录数，防止大规模同时登录造成 O(N²) 瞬时分配峰值 OOM
        loginGate.acquire()
        try {
            this.handleAddClientInner(user, line)
        } finally {
            loginGate.release()
        }
    }

    private func handleAddClientInner(user: ClUser, line: String): Unit {
        let prefix = if (line.startsWith("#AA")) { "#AA" } else { "#AP" }
        let data = substrFrom(line, Int64(prefix.toRuneArray().size))
        let parts = splitStr(data, ":")
        if (parts.size < 2) { sendError(user, ERR_SYNTAX, "unknown", "unknown"); return }

        let callsign = parts[0].toUpper()  // 统一大写
        // 字段长度限制
        if (callsign.toRuneArray().size > Int64(CALLSIGNBYTES)) { sendError(user, ERR_CSINVALID, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
        // 呼号字符白名单：仅允许 A-Z 0-9 _ -（防协议/边界注入）
        if (!isValidCallsign(callsign)) { sendError(user, ERR_CSINVALID, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
        if (parts.size < 7) { sendError(user, ERR_SYNTAX, callsign, callsign); return }
        if (parts[2].toRuneArray().size > 64 || parts[3].toRuneArray().size > 64 || parts[4].toRuneArray().size > 128) { sendError(user, ERR_SYNTAX, callsign, callsign); user.shouldClose = true; user.delayClose = true; return }

        // 检查是否禁止的航班号
        if (isBlockedFlight(callsign)) {
            sendTo(user, "#TMserver:${callsign}:Flight number blocked, please change your callsign\r\n")
            user.shouldClose = true; user.delayClose = true
            return
        }

        // parts[1] = "SERVER" (literal, skip)
        let isAtc = (prefix == "#AA")

        if (isAtc) {
            // #AA: callsign:SERVER:realname:cid:password:rating:protocol
            if (parts.size < 7) { sendError(user, ERR_SYNTAX, callsign, callsign); return }
            let realname = parts[2]; let cid = parts[3]; let password = parts[4]
            let rating = parseInt32(parts[5]); let protocol = parseInt32(parts[6])
            if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (protocol != NEEDREVISION) { sendError(user, ERR_REVISION, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            let (verified, actualLevel) = verifyUser(cid, password)
            if (!verified) { sendError(user, ERR_CIDINVALID, cid, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (actualLevel <= LEV_SUSPENDED) { sendError(user, ERR_CSSUSPEND, cid, "unknown"); return }
            let req = if (rating < 0) { 0i32 } else { rating }
            if (actualLevel < req) { sendError(user, ERR_LEVEL, callsign, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            // CID 唯一性检查：同一 CID 不能重复登录（仅 OBS 豁免）
            match (getClientByCid(cid)) {
                case Some(existing) =>
                    let exCsLen = Int64(existing.callsign.toRuneArray().size)
                    if (!(exCsLen > 4 && substrFrom(existing.callsign, exCsLen - 4) == "_OBS")) {
                        sendError(user, ERR_CSINUSE, "", "unknown")
                        user.shouldClose = true; user.delayClose = true; return
                    }
                case None => ()
            }
            let client = Client(callsign, cid, realname, CLIENT_ATC, actualLevel, protocol)
            client.location = myServer
            if (!addClient(client)) { sendError(user, ERR_CSINUSE, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            user.client = client
            dolog(L_INFO, "ATC login: ${callsign} level=${actualLevel} ip=${user.peerIp}")
            sendAllClientsTo(user)
        } else {
            // #AP: callsign:SERVER:cid:password:rating:protocol:simtype:realname
            if (parts.size < 8) { sendError(user, ERR_SYNTAX, callsign, callsign); return }
            let cid = parts[2]; let password = parts[3]
            let rating = parseInt32(parts[4]); let protocol = parseInt32(parts[5])
            let simtype = parseInt32(parts[6]); let realname = parts[7]
            let csLen = Int64(callsign.toRuneArray().size)
            let isObserver = (csLen > 4 && substrFrom(callsign, csLen - 4) == "_OBS")
            if (isObserver) {
                // 限制每个呼号只能有一个OBS
                if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            } else {
                if (let Some(_) <- getClient(callsign)) { sendError(user, ERR_CSINUSE, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            }
            if (protocol != NEEDREVISION) { sendError(user, ERR_REVISION, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            let (verified, actualLevel) = verifyUser(cid, password)
            if (!verified) { sendError(user, ERR_CIDINVALID, cid, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            if (actualLevel <= LEV_SUSPENDED) { sendError(user, ERR_CSSUSPEND, cid, "unknown"); return }
            let reqP = if (rating < 0) { 0i32 } else { rating }
            if (actualLevel < reqP) { sendError(user, ERR_LEVEL, callsign, "unknown"); user.shouldClose = true; user.delayClose = true; return }
            // CID 唯一性检查：非 OBS 连接才检查
            if (!isObserver) {
                match (getClientByCid(cid)) {
                    case Some(existing) =>
                        let exCsLen = Int64(existing.callsign.toRuneArray().size)
                        if (!(exCsLen > 4 && substrFrom(existing.callsign, exCsLen - 4) == "_OBS")) {
                            sendError(user, ERR_CSINUSE, "", "unknown")
                            user.shouldClose = true; user.delayClose = true; return
                        }
                    case None => ()
                }
            }
            let client = Client(callsign, cid, realname, CLIENT_PILOT, actualLevel, protocol)
            client.location = myServer; client.simtype = simtype
            if (!addClient(client)) { sendError(user, ERR_CSINUSE, "", "unknown"); user.shouldClose = true; user.delayClose = true; return }
            user.client = client
            dolog(L_INFO, "${if (isObserver) { "Observer" } else { "Pilot" }} login: ${callsign} level=${actualLevel} ip=${user.peerIp}")
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
                        let idx2 = rawData.indexOf(r':')
                        match (idx2) {
                            case Some(pos2) =>
                                let afterServer = substrFrom(rawData, pos2 + 1)
                                let idx3 = afterServer.indexOf(r':')
                                match (idx3) {
                                    case Some(pos3) =>
                                        let fpData = substrFrom(afterServer, pos3 + 1)
                                        let fp = FlightPlan.parse(fpData); fp.callsign = callsign; fp.cid = c.cid
                                        // 机组只能改自己的计划
                                        if (callsign.toUpper() != c.callsign.toUpper()) {
                                            sendError(user, ERR_LEVEL, callsign, c.callsign); return
                                        }
                                        // 若被其他管制锁定则拒绝
                                        if (c.planLockedBy != "" && c.planLockedBy != c.callsign) {
                                            sendTo(user, "#TMserver:${c.callsign}:Flight plan locked by ${c.planLockedBy}\r\n")
                                            return
                                        }
                                        c.plan = fp
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

    // ---- $AM 管制修改机组飞行计划（CL_TAGMOD）----
    public func handleTagMod(user: ClUser, line: String): Unit {
        dolog(L_INFO, "TAGMOD: ${line}")
        match (user.client) {
            case Some(c) =>
                // 格式: $AM<source>:SERVER:<target>:<type>:<plan...>
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                if (parts.size < 18) { return }
                // parts[2] = target callsign, parts[3] = type, parts[4..] = plan
                let targetCs = parts[2]
                if (!c.isAtc() || c.rating < 5) { sendError(user, ERR_LEVEL, targetCs, c.callsign); return }
                // 重组 plan 数据（parts[4..]，用 : 连接，route 可能含 :）
                var fpData = ""
                for (i in 4..parts.size) {
                    if (fpData != "") { fpData += ":" }
                    fpData += parts[Int64(i)]
                }
                match (getClient(targetCs)) {
                    case Some(pilot) =>
                        let fp = FlightPlan.parse(fpData); fp.callsign = targetCs; fp.cid = pilot.cid
                        pilot.plan = fp
                        pilot.planLockedBy = c.callsign
                        dolog(L_INFO, "PLAN: ${c.callsign} modified ${targetCs} plan")
                        match (gMysql) { case Some(db) => db.saveFlightPlan(targetCs, pilot.cid, fpData); case None => () }
                        broadcastToClients("\$FP${targetCs}:SERVER:${fp.`type`}:${fp.serialize()}\r\n", None)
                        serverInterface?.sendPlan("*", pilot, None)
                    case None =>
                        sendTo(user, "#TMserver:${c.callsign}:${targetCs} not found\r\n")
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
            // 从 PBH 解码航向（10 位精度，地面静止时也有数据）
            let pbhVal = c.pbh
            var pbhHeading: Float64 = 0.0
            if (pbhVal > 0) {
                let hBits = (Int64(pbhVal) >> 2) & 0x3FF
                pbhHeading = Float64(hBits) * 360.0 / 1024.0
            }
            // 从前后位置计算方位角（移动时更准）
            var posHeading: Float64 = 0.0
            if (c.prevLat != 0.0 || c.prevLon != 0.0) {
                posHeading = calcBearing(c.prevLat, c.prevLon, c.lat, c.lon)
            }
            c.prevLat = c.lat; c.prevLon = c.lon
            // 优先用位置算的航向（移动时），静止时回退到 PBH
            var finalHeading = pbhHeading
            if (posHeading > 0.0) { finalHeading = posHeading }
            c.headingCalc = finalHeading
            // 飞行记录（缓冲到全局 replayBuf，定时刷盘）
            let ts = sprintGmt(mgmtime())
            replayLock.lock()
            if (replayBuf.size < 1048576) {  // 限制最大 1MB
                replayBuf += "${ts} ${c.callsign} ${c.lat} ${c.lon} ${c.altitude} ${Int64(finalHeading)} ${c.groundspeed}\n"
            }
            replayLock.unlock()
            // C 版 sendpacket 范围过滤广播：data 不含 @/% 和 \r\n
            let cmd: Int32 = if (c.isAtc()) { 8i32 } else { 7i32 }  // CL_ATCPOS=8, CL_PILOTPOS=7
            sendPacket(Some(c), None, Some(c), CLIENT_ALL, Int32(-1), cmd, data)
        ; case None => () }
    }

    // ---- $CQ 查询 / $CR 响应 ----
    public func handleCq(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3); let parts = splitStr(data, ":")
                if (parts.size < 3) { return }
                // C 版: array[1]==target, array[2]==cmd
                // 格式 $CQ:source:target:cmd... → parts[1]=source, parts[2]=target
                let source = if (parts[0] == "") { parts[1] } else { parts[0] }
                let target = if (parts[0] == "") { parts[2] } else { parts[1] }
                // 非 "server" 目标 → 转发给目标客户端（保持 $CQ 前缀）
                if (target.toUpper() != "server") {
                    match (getClient(target)) {
                        case Some(cl) =>
                            sendPacket(Some(c), Some(cl), None, CLIENT_ALL, Int32(-1), CL_CQ, data)
                        case None => ()
                    }
                    // 如果目标不在本地，通过服务器间路由
                    serverInterface?.sendMulticast(c.callsign, target, data, CL_CQ)
                    return
                }
                // server 命令: parts = ["", source, "server", cmd, ...]
                let cmdStr = if (parts[0] == "") { if (parts.size > 3) { parts[3] } else { "" } } else { parts[2] }
                if (cmdStr.toUpper() == "RN") {
                    let queryTarget = if (parts[0] == "") { if (parts.size > 4) { parts[4] } else { "" } } else { if (parts.size > 3) { parts[3] } else { "" } }
                    if (queryTarget != "") {
                        match (getClient(queryTarget)) {
                            case Some(targetCl) =>
                                user.outStr += "\$CR${c.callsign}:${targetCl.callsign}:RN:${targetCl.realname}:USER:${targetCl.rating}\r\n"
                            case None => ()
                        }
                    }
                } else if (cmdStr.toUpper() == "FP") {
                    let queryTarget = if (parts[0] == "") { if (parts.size > 4) { parts[4] } else { "" } } else { if (parts.size > 3) { parts[3] } else { "" } }
                    if (queryTarget != "") {
                        match (getClient(queryTarget)) {
                            case Some(targetCl) =>
                                match (targetCl.plan) {
                                    case Some(fp) =>
                                        user.outStr += "\$FP${queryTarget}:SERVER:${fp.`type`}:${fp.serialize()}\r\n"
                                    case None => sendError(user, ERR_NOFP, queryTarget, c.callsign)
                                }
                            case None => sendError(user, ERR_NOSUCHCS, queryTarget, c.callsign)
                        }
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
                if (line.size > 3) { broadcastToClients(line + "\r\n", c.callsign) }
            case None => ()
        }
    }

    // ---- $HA 移交确认（Handoff Accept）----
    public func handleHandoffAccept(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                if (line.size > 3) { broadcastToClients(line + "\r\n", c.callsign) }
            case None => ()
        }
    }

    // ---- $C? 通信请求 ----
    public func handleCommsRequest(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                if (line.size > 3) { broadcastToClients(line + "\r\n", c.callsign) }
            case None => ()
        }
    }

    // ---- $CI 通信回复 ----
    public func handleCommsReply(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                if (line.size > 3) { broadcastToClients(line + "\r\n", c.callsign) }
            case None => ()
        }
    }

    // ---- #PC 管制协调协议（C 版 execmulticast，只发给目标）----
    public func handlePilotCommand(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                // #PCsource:target:data... → parts[1] = target
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                if (parts.size >= 2) {
                    let target = parts[1]
                    match (getClient(target)) {
                        case Some(cl) =>
                            sendPacket(Some(c), Some(cl), None, CLIENT_ALL, Int32(-1), CL_PC, data)
                        case None => ()
                    }
                    // multiok=0，不转发服务器间
                }
            case None => ()
        }
    }

    // ---- #CD 气象云层数据 / #WD 风数据 / #TD 温度数据 ----
    public func handleWeatherData(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                // 广播给同频率客户端
                broadcastToClients(line + "\r\n", c.callsign)
            case None => ()
        }
    }

    // ---- $AX ACARS 请求 ----
    public func handleAcars(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                if (parts.size >= 2) {
                    let source = parts[0]
                    if (source.toUpper() != c.callsign.toUpper()) { sendError(user, ERR_SRCINVALID, source, c.callsign); return }
                    if (parts.size >= 4 && parts[2].toUpper() == "METAR") {
                        match (metarManager) {
                            case Some(mm) => mm.requestMetar("%${c.callsign}", parts[3], 0, Int32(-1))
                            case None => ()
                        }
                        return
                    }
                    routeMessage(c.callsign, parts[1], line)
                }
            case None => ()
        }
    }

    // ---- $CR 查询回复（C 版 execmulticast，转发给目标）----
    public func handleCr(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                // $CRsource:target:cmd:data
                if (parts.size >= 2) {
                    sendPacket(Some(c), None, None, CLIENT_ALL, Int32(-1), CL_CR, data)
                    // 不转发到其他服务器（multiok=0）
                }
            case None => ()
        }
    }

    // ---- $!! 管理员命令 ----
    public func handleKill(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let after = substrFrom(line, 3)
                let parts = splitStr(after, ":")
                if (parts.size < 3) { return }
                match (getClient(parts[1])) {
                    case Some(cl) =>
                        if (c.rating >= 11) {
                            dolog(L_INFO, "KILL: ${c.callsign} -> ${cl.callsign} (reason=${parts[2]})")
                            broadcastToClients("#TMserver:${c.callsign}:Attempting to kill ${cl.callsign}\r\n", None)
                            serverInterface?.sendKill(cl.callsign, parts[2])
                        } else {
                            user.outStr += "#TMserver:${c.callsign}:You are not allowed to kill users!\r\n"
                        }
                    case None => broadcastToClients("#TMserver:${c.callsign}:Could not find ${parts[1]}\r\n", None)
                }
            case None => ()
        }
    }

    // ---- $PI/$PO 客户端 Ping/Pong（C 版 execmulticast 转发给目标）----
    public func handlePing(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                if (parts.size >= 2) {
                    sendPacket(Some(c), None, None, CLIENT_ALL, Int32(-1), CL_PING, data)
                    serverInterface?.sendMulticast(c.callsign, parts[1], data, CL_PING)
                }
            case None => ()
        }
    }
    public func handlePong(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                if (parts.size >= 2) {
                    sendPacket(Some(c), None, None, CLIENT_ALL, Int32(-1), CL_PONG, data)
                    serverInterface?.sendMulticast(c.callsign, parts[1], data, CL_PONG)
                }
            case None => ()
        }
    }

    // ---- #RW 天气请求 ----
    public func handleWeatherRequest(user: ClUser, line: String): Unit {
        match (user.client) {
            case Some(c) =>
                let data = substrFrom(line, 3)
                let parts = splitStr(data, ":")
                if (parts.size >= 2) {
                    let target = parts[1]
                    sendPacket(None, None, None, CLIENT_ATC, Int32(-1), CL_REQWEATHER, data)
                    serverInterface?.sendMulticast(c.callsign, target, data, CL_REQWEATHER)
                }
            case None => ()
        }
    }

    // ---- 广播 ----
    // C 版 calcrange: 计算两个客户端之间的可见范围（NM）
    private func calcRange(from: Client, to: Client, cmd: Int32, range: Int32): Int32 {
        // CL_PILOTPOS=7, CL_ATCPOS=8
        if (cmd == 7 || cmd == 8) {
            if (to.isAtc()) { return to.visualrange }
            let x = to.getrange(); let y = from.getrange()
            if (from.isPilot()) { return x + y }
            return if (x > y) { x } else { y }
        }
        // CL_MESSAGE=5
        if (cmd == 5) {
            let x = to.getrange(); let y = from.getrange()
            if (from.isPilot() && to.isPilot()) { return x + y }
            return if (x > y) { x } else { y }
        }
        return range
    }

    // C 版 sendpacket: 按范围过滤广播
    public func sendPacket(source: ?Client, dest: ?Client, exclude: ?Client,
                           broad: Int32, range: Int32, cmd: Int32, data: String): Unit {
        let line = "${clcmdnames(cmd)}${data}\r\n"
        let lineBytes = line.toArray()
        synchronized(this.usersLock) {
        for (_ui in 0..this.users.size) {
            let u = this.users[_ui]
            match (u) { case cu: ClUser => match (cu.client) {
                case Some(cl) =>
                    if (let Some(ex) <- exclude) { if (cl.callsign == ex.callsign) { continue } }
                    if (let Some(d) <- dest) { if (cl.callsign != d.callsign) { continue } }
                    if ((cl.`type` & broad) == 0) { continue }
                    if (let Some(s) <- source) {
                        if (range != -1 || cmd == 7 || cmd == 8) {
                            let cr = calcRange(s, cl, cmd, range)
                            let dist = s.distanceNM(cl)
                            if (dist < 0.0 || dist > Float64(cr)) { continue }
                        }
                    }
                    sendBytesTo(cu, lineBytes)
                case None => ()
            }; case _ => () }
        }
        }
    }

    private func clcmdnames(cmd: Int32): String {
        // clcmdnames array from C: #AA #DA #AP #DP $HO #TM #RW @ % $PI $PO $HA $FP #SB #PC #WX #CD #WD #TD $C? $CI $AX $AR $ER $CQ $CR $!!
        let names = ["#AA", "#DA", "#AP", "#DP", "\$HO", "#TM", "#RW", "@", "%",
                     "\$PI", "\$PO", "\$HA", "\$FP", "#SB", "#PC", "#WX",
                     "#CD", "#WD", "#TD", "\$C?", "\$CI", "\$AX", "\$AR", "\$ER",
                     "\$CQ", "\$CR", "\$!!"]
         if (cmd >= 0 && Int64(cmd) < names.size) { return names[Int64(cmd)] }
        return ""
    }

    public func broadcastToClients(data: String, exclude: ?String): Unit {
        let bytes = data.toArray()
        synchronized(this.usersLock) {
        for (_ui in 0..this.users.size) {
            let u = this.users[_ui]
            match (u) { case cu: ClUser =>
                if (let Some(c) <- cu.client) {
                    match (exclude) { case Some(cs) => if (c.callsign == cs) { continue }; case None => () }
                    sendBytesTo(cu, bytes)
                }
            ; case _ => () }
        }
        }
    }

    public func sendAllClientsTo(user: ClUser): Unit {
        let sb = StringBuilder()
        let _keys = getClientKeys()
        for (_i in 0.._keys.size) {
            if (let Some(c) <- clientMap.get(_keys[_i])) {
                match (user.client) {
                    case Some(myC) =>
                        if (c.callsign != myC.callsign) {
                            sb.append(buildAddClientLine(c))
                            if (let Some(fp) <- c.plan) {
                                sb.append("\$FP${c.callsign}:SERVER:${fp.`type`}:${fp.serialize()}\r\n")
                            }
                            // 同步ATC频率/位置（即使频率为0也发，客户端自行解析）
                            if (c.isAtc()) {
                                sb.append("%${c.callsign}:${c.frequency}:${c.facilitytype}:${c.visualrange}:${c.rating}:${c.lat}:${c.lon}:${c.altitude}\r\n")
                            }
                        }
                    case None => ()
                }
            }
        }
        sendTo(user, sb.toString())
    }

    public func routeMessage(from: String, target: String, msg: String): Unit {
        let line = "#TM${from}:${target}:${msg}\r\n"
        let lineBytes = line.toArray()
        // 解析 @ 频率目标
        let targetFreq: Int32 = if (target.startsWith("@") && target.toRuneArray().size > 1) {
            let freqStr = substrFrom(target, 1)
            // "122.800" → 122800
            let dotPos = freqStr.indexOf(r'.')
            match (dotPos) {
                case Some(pos) =>
                    let whole = parseInt32(substrTo(freqStr, pos))
                    let frac = parseInt32(substrFrom(freqStr, pos + 1))
                    whole * 1000 + (frac % 1000)
                case None => parseInt32(freqStr) * 1000
            }
        } else { 0 }
        synchronized(this.usersLock) {
        for (_ui in 0..this.users.size) {
            let u = this.users[_ui]
            match (u) { case cu: ClUser => match (cu.client) {
                case Some(c) =>
                    var deliver = false
                    if (target == "*") { deliver = c.callsign != from }
                    else if (target == "*A") { deliver = c.isAtc() && c.callsign != from }
                    else if (target == "*P") { deliver = c.isPilot() && c.callsign != from }
                    else if (target.startsWith("@")) {
                        if (targetFreq != 0) {
                            // @freq：同频率才转发
                            deliver = c.frequency == targetFreq && c.callsign != from
                        } else {
                            // @ 无频率：发给同服务器所有客户端
                            deliver = c.callsign != from
                        }
                    }
                    else { deliver = (c.callsign == target) }
                    if (deliver) { sendBytesTo(cu, lineBytes) }
                case None => ()
            }; case _ => () }
        }
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

        // 目标以 @ 开头 = 频率广播，转发给同频率的客户端
        var isFreqBcast = false
        if (targetEnd > targetStart && bytes[targetStart] == UInt8(64)) {  // '@'
            isFreqBcast = true
        }

        // 分发到所有匹配的客户端
        let outBytes = out.toArray()
        synchronized(this.usersLock) {
        for (_ui in 0..this.users.size) {
            let u = this.users[_ui]
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
                        sendBytesTo(cu, outBytes)
                    }
                case None => ()
            }; case _ => () }
        }
        }
    }

    public func sendAddA(client: Client): Unit {
        broadcastToClients("#AA${client.callsign}:SERVER:${client.realname}:${client.cid}::${client.rating}:${client.protocol}\r\n", client.callsign)
    }
    public func sendAddP(client: Client): Unit {
        broadcastToClients("#AP${client.callsign}:SERVER:${client.cid}::${client.rating}:${client.protocol}:${client.simtype}\r\n", client.callsign)
    }
    public func sendRemoveClient(client: Client): Unit {
        let prefix = if (client.isAtc()) { "#DA" } else { "#DP" }
        broadcastToClients("${prefix}${client.callsign}:${client.cid}\r\n", None)
    }
    public func sendKillClient(client: Client, reason: String): Unit {
        let msg = "\$!!SERVER:${client.callsign}:${reason}\r\n"
        dolog(L_INFO, "KILL NOTIFY: ${msg.trim()}")
        broadcastToClients(msg, None)
        // 不发 #DP/#DA——让客户端自行从 $!!SERVER 处理移除
        removeClient(client)
        serverInterface?.sendRmClient("*", client.callsign, None)
        // sendTo 已直写 socket，无需手动 flush
        synchronized(this.usersLock) {
            for (j in 0..this.users.size) {
                match (this.users[Int64(j)]) {
                    case cu: ClUser => match (cu.client) {
                        case Some(c) => if (c.callsign == client.callsign) {
                            cu.shouldClose = true; cu.outStr.close()   // 先冲刷 $!! 再关闭
                        }
                        case None => ()
                    }; case _ => ()
                }
            }
        }
    }

    // 停机：给每个在线客户端单独发 $!!（客户端识别后会自行离开），并优雅关闭连接
    public func notifyAllShutdown(reason: String): Unit {
        synchronized(this.usersLock) {
            for (j in 0..this.users.size) {
                match (this.users[Int64(j)]) {
                    case cu: ClUser => match (cu.client) {
                        case Some(c) =>
                            sendTo(cu, "\$!!SERVER:${c.callsign}:${reason}\r\n")
                            cu.shouldClose = true
                            cu.outStr.close()
                        case None => ()
                    }; case _ => ()
                }
            }
        }
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
        let bytes = data.toArray()
        synchronized(this.usersLock) {
        for (_ui in 0..this.users.size) { sendBytesTo(this.users[_ui], bytes) }
        }
    }

    public func broadcastWeatherProfile(wp: WeatherProfile): Unit {
        let bytes = (wp.toWxMessage("server") + "\r\n" + wp.toCdMessage() + "\r\n").toArray()
        synchronized(this.usersLock) {
        for (_ui in 0..this.users.size) { sendBytesTo(this.users[_ui], bytes) }
        }
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
                dolog(L_INFO, "CLIENT DISCONNECT: ${c.callsign} (CID:${c.cid}) type=${ctype} duration=${durationMin}min ip=${this.peerIp}")
                // 先清理注册表：DB 统计可能阻塞或抛异常，不能让它把用户永久卡在在线列表
                serverInterface?.sendRmClient("*", c.callsign, None); removeClient(c); this.iface.sendRemoveClient(c); fsdEngine?.markWhazzupDirty()
                // 管制断线：解锁其锁定的飞行计划
                if (c.isAtc()) { unlockPlansBy(c.callsign) }
                // 保存连线时长到数据库（区分飞行员/管制员，OBS 不计入）
                let csLen = Int64(c.callsign.toRuneArray().size)
                let isObs = (csLen > 4 && substrFrom(c.callsign, csLen - 4) == "_OBS")
                if (!isObs && durationMin > 0) {
                    if (!(gMysql?.saveOnlineTime(c.cid, ctype, durationMin) ?? false)) {
                        dolog(L_WARNING, "DB stats failed for ${c.callsign}, fallback to file")
                        _saveStatsToFile(c.cid, c.callsign, ctype, durationMin)
                    }
                }
                // 断线清除轨迹（放最后，避免阻塞前面的清理）
                if (c.isPilot()) { gMysql?.deleteFlightTrails(c.callsign) }
            case None => ()
        }
        if (this.delayClose) {
            sleep(200 * Duration.millisecond)  // 给 TCP 时间刷新数据到客户端
        }
        this.outStr.close()
        // 连接从 users 列表的移除由 NetInterface.serve 统一按 id 处理
        // （原先按 callsign 匹配只覆盖已登录用户，未登录连接会永久泄漏）
    }
    public override func handleLine(line: String): Unit {
        let trimmed = line.trimAscii()
        if (trimmed.isEmpty()) { return }
        // 按首字节分组，减少重复 startsWith 比较
        let c0 = trimmed[0]
        if (c0 == UInt8(35)) {          // '#'
            if (trimmed.startsWith("#AA") || trimmed.startsWith("#AP")) { this.iface.handleAddClient(this, trimmed) }
            else if (trimmed.startsWith("#WX")) { this.iface.handleWeather(this, trimmed) }
            else if (trimmed.startsWith("#RW")) { this.iface.handleWeatherRequest(this, trimmed) }
            else if (trimmed.startsWith("#PC")) { this.iface.handlePilotCommand(this, trimmed) }
            else if (trimmed.startsWith("#CD") || trimmed.startsWith("#WD") || trimmed.startsWith("#TD") || trimmed.startsWith("#DL")) { this.iface.handleWeatherData(this, trimmed) }
            else if (trimmed.startsWith("#DA") || trimmed.startsWith("#DP")) {
                // C 版: #DA(ATC下线)/#DP(机组下线) 都是通知自己离线的，不踢人
                // 踢人通过 $!!target:reason (handleKill)
                if (let Some(c) <- this.client) {
                    let durationMin = (mgmtime() - c.startTime) / 60
                    let ctype = if (c.isAtc()) { "ATC" } else { "PILOT" }
                    dolog(L_INFO, "CLIENT DISCONNECT: ${c.callsign} (CID:${c.cid}) type=${ctype} duration=${durationMin}min ip=${this.peerIp}")
                    // 先清理注册表，再做 DB 统计（DB 可能阻塞/异常，不能卡住在在线列表）
                    this.iface.sendRemoveClient(c)
                    serverInterface?.sendRmClient("*", c.callsign, None)
                    removeClient(c)
                    fsdEngine?.markWhazzupDirty()
                    if (c.isAtc()) { unlockPlansBy(c.callsign) }
                    let csLen = Int64(c.callsign.toRuneArray().size)
                    let isObs = (csLen > 4 && substrFrom(c.callsign, csLen - 4) == "_OBS")
                    if (!isObs && durationMin > 0) {
                        if (!(gMysql?.saveOnlineTime(c.cid, ctype, durationMin) ?? false)) {
                            dolog(L_WARNING, "DB stats failed for ${c.callsign}, fallback to file")
                            _saveStatsToFile(c.cid, c.callsign, ctype, durationMin)
                        }
                    }
                    if (c.isPilot()) { gMysql?.deleteFlightTrails(c.callsign) }
                }
                this.client = None
                this.shouldClose = true
                this.outStr.close()
            }
        } else if (c0 == UInt8(36)) {   // '$'
            if (trimmed.startsWith("\$FP")) { this.iface.handleFlightPlan(this, trimmed) }
            else if (trimmed.startsWith("\$AM")) { this.iface.handleTagMod(this, trimmed) }
            else if (trimmed.startsWith("\$CQ")) { this.iface.handleCq(this, trimmed) }
            else if (trimmed.startsWith("\$PI")) { this.iface.handlePing(this, trimmed) }
            else if (trimmed.startsWith("\$PO")) { this.iface.handlePong(this, trimmed) }
            else if (trimmed.startsWith("\$HO")) { this.iface.handleHandoff(this, trimmed) }
            else if (trimmed.startsWith("\$HA")) { this.iface.handleHandoffAccept(this, trimmed) }
            else if (trimmed.startsWith("\$C?")) { this.iface.handleCommsRequest(this, trimmed) }
            else if (trimmed.startsWith("\$CI")) { this.iface.handleCommsReply(this, trimmed) }
            else if (trimmed.startsWith("\$AX")) { this.iface.handleAcars(this, trimmed) }
            else if (trimmed.startsWith("\$CR")) { this.iface.handleCr(this, trimmed) }
            else if (trimmed.startsWith("\$!!")) { this.iface.handleKill(this, trimmed) }
        } else if (c0 == UInt8(64) || c0 == UInt8(37)) {   // '@' 或 '%'
            this.iface.handlePosition(this, trimmed)
        }
    }
    // 原始字节处理（非 UTF-8 编码，如 GBK 中文）
    public override func handleRawLine(bytes: ArrayList<UInt8>): Unit {
        this.iface.handleRawTextMessage(this, bytes)
    }
}

// 管制断线时解锁其锁定的所有飞行计划
func unlockPlansBy(controllerCallsign: String): Unit {
    let _keys = getClientKeys()
    var unlocked = 0
    for (_i in 0.._keys.size) {
        if (let Some(c) <- clientMap.get(_keys[_i])) {
            if (c.planLockedBy == controllerCallsign) {
                c.planLockedBy = ""
                unlocked += 1
            }
        }
    }
    if (unlocked > 0) { dolog(L_INFO, "Unlocked ${unlocked} flight plans by ${controllerCallsign}") }
}

// 检查呼号是否包含禁止的航班号
func isBlockedFlight(callsign: String): Bool {
    blockedLock.lock()
    let bf = blockedFlights
    blockedLock.unlock()
    if (bf == "") { return false }
    let cs = callsign.toUpper()
    let items = splitStr(bf, ",")
    for (i in 0..items.size) {
        let num = items[Int64(i)].trim().toUpper()
        if (num == "") { continue }
        if (cs.contains(num)) { return true }
    }
    return false
}

// 回退：当 MySQL 不可用时将统计写入文件
func _saveStatsToFile(cid: String, callsign: String, ctype: String, durationMin: Int64): Unit {
    statsLock.lock()
    try {
        let line = "${cid}:${callsign}:${mgmtime()}:${ctype}:${durationMin}\n"
        File.appendTo(Path("stats.txt"), line.toArray())
        dolog(L_INFO, "Stats file fallback: ${callsign} ${durationMin}min")
    } catch (e: Exception) {
        dolog(L_ERR, "Stats file error: ${e}")
    }
    statsLock.unlock()
}
