package FSD_Cangjie

import std.fs.*
import std.process.*
import std.collection.*
import std.sync.*

var clientInterface: ?ClInterface = None
var serverInterface: ?ServInterface = None
var systemInterface: ?SysInterface = None
var configMan: ?ConfigManager = None
var metarManager: ?MetarManager = None
var fsdEngine: ?FsdEngine = None
var replayBuf: String = ""
var replayLock = Mutex()
var blockedFlights: String = ""
var blockedLock = Mutex()

public class FsdEngine {
    var certFile: ?String; var whazzupFile: ?String
    var prevNotify: Int64; var prevLagCheck: Int64; var prevCertCheck: Int64; var prevWhazzup: Int64
    var whazzupDirty: Bool
    var prevHeartbeat: Int64
    var prevDbCheck: Int64
    var prevWindDelta: Int64
    var prevTrailSave: Int64
    var prevUserCheck: Int64
    var trailEnabled: Bool
    var voiceSrv: ?VoiceServer
    var timer: Int64; var clientPort: Int32; var serverPort: Int32; var systemPort: Int32

    public init(configFile: String) {
        this.certFile = None; this.whazzupFile = None
        this.prevNotify = 0; this.prevLagCheck = 0; this.prevCertCheck = 0; this.prevWhazzup = 0
        this.whazzupDirty = false
        this.prevHeartbeat = 0
        this.prevWindDelta = 0
        this.prevTrailSave = 0
        this.prevUserCheck = 0
        this.trailEnabled = false
        this.prevDbCheck = 0
        this.voiceSrv = None
        this.timer = 0; this.clientPort = DEFAULT_CLIENT_PORT
        this.serverPort = DEFAULT_SERVER_PORT; this.systemPort = DEFAULT_SYSTEM_PORT

        dolog(L_INFO, "Booting FSD server v${VERSION}")
        configMan = ConfigManager(configFile); metarManager = MetarManager()
        configure(); initDatabase(); initHttpApi(); createInterfaces(); makeConnections()
        var vs = VoiceServer(); vs.start(6808); this.voiceSrv = Some(vs)
        dolog(L_INFO, "FSD server is up and running")
        this.prevNotify = mgmtime(); this.prevLagCheck = mgmtime()
        this.timer = mgmtime(); this.prevWhazzup = mgmtime()
        this.prevHeartbeat = mgmtime()
        this.prevDbCheck = mgmtime()
        this.prevWindDelta = mgmtime()
    }

    public func configure(): Unit {
        match (configMan) { case Some(cm) => match (cm.getGroup("system")) {
            case Some(g) =>
                this.clientPort = gPort(g, "clientport", DEFAULT_CLIENT_PORT)
                this.serverPort = gPort(g, "serverport", DEFAULT_SERVER_PORT)
                this.systemPort = gPort(g, "systemport", DEFAULT_SYSTEM_PORT)
                this.certFile = match (g.getEntry("certificates")) { case Some(e) => e.getData(); case None => None }
                this.whazzupFile = match (g.getEntry("whazzup")) { case Some(e) => e.getData(); case None => None }
                let bf = match (g.getEntry("blocked_flights")) { case Some(e) => e.getData(); case None => "" }
                blockedFlights = bf
                if (bf != "") { dolog(L_INFO, "Blocked flights: ${bf}") }
                match (g.getEntry("maxclients")) { case Some(e) => let mc = e.getInt(); if (mc > 0) { MAX_CLIENTS = Int32(mc) }; dolog(L_INFO, "Max clients: ${MAX_CLIENTS}"); case None => () }
            case None => ()
        }; case None => () }
        configMyServer()
        readCert()
        // 检查系统端口是否仍使用默认密码
        match (configMan) { case Some(cm) => match (cm.getGroup("system")) {
            case Some(g) => match (g.getEntry("password")) {
                case Some(e) => if (e.getData() == "disable") { dolog(L_WARNING, "Default system password 'disable' in use! Change it in fsd.conf") }
                case None => ()
            }; case None => ()
        }; case None => () }
    }

    public func configMyServer(): Unit {
        var si = "FSD"; var sn = "FSD Cangjie"; var se = "nobody@nowhere.com"
        var sh = "localhost"; var sl = "Unknown"; var mode: Int32 = 0
        match (configMan) { case Some(cm) => match (cm.getGroup("system")) {
            case Some(g) => g.changed = false
                si = gStr(g, "ident", si); sn = gStr(g, "name", sn); se = gStr(g, "email", se)
                sh = gStr(g, "hostname", sh); sl = gStr(g, "location", sl)
                match (g.getEntry("mode")) { case Some(e) => if (e.getData() == "silent") { mode = SERVER_SILENT }; case None => () }
            case None => ()
        }; case None => () }
        var flags = mode
        match (metarManager) { case Some(mm) => if (mm.source != SOURCE_NETWORK) { flags |= SERVER_METAR }; case None => () }
        match (myServer) {
            case Some(s) => s.configure(sn, se, sh, VERSION, sl)
            case None => let s = Server(si, sn, se, sh, VERSION, flags, sl); myServer = s; addServer(s)
        }
    }

    public func initDatabase(): Unit {
        match (configMan) { case Some(cm) => match (cm.getGroup("database")) {
            case Some(g) =>
                let host = match (g.getEntry("host")) { case Some(e) => e.getData(); case None => "localhost" }
                let user = match (g.getEntry("user")) { case Some(e) => e.getData(); case None => "root" }
                let password = match (g.getEntry("password")) { case Some(e) => e.getData(); case None => "" }
                let name = match (g.getEntry("name")) { case Some(e) => e.getData(); case None => "飞控" }
                var port: Int32 = 3306
                match (g.getEntry("port")) { case Some(e) => port = Int32(e.getInt()); case None => () }
                let tu = match (g.getEntry("table_users")) { case Some(e) => e.getData(); case None => "useraccount" }
                let tf = match (g.getEntry("table_flightplans")) { case Some(e) => e.getData(); case None => "flightplans" }
                let cuc = match (g.getEntry("col_user_callsign")) { case Some(e) => e.getData(); case None => "callsign" }
                let cup = match (g.getEntry("col_user_password")) { case Some(e) => e.getData(); case None => "password" }
                let cupr = match (g.getEntry("col_user_permission")) { case Some(e) => e.getData(); case None => "permission" }
                let fpc = match (g.getEntry("col_fp_callsign")) { case Some(e) => e.getData(); case None => "callsign" }
                let fpid = match (g.getEntry("col_fp_cid")) { case Some(e) => e.getData(); case None => "cid" }
                let fpda = match (g.getEntry("col_fp_data")) { case Some(e) => e.getData(); case None => "fp_data" }
                let db = MysqlDB(host, user, password, name, port, tu, tf, cuc, cup, cupr, fpc, fpid, fpda)
                if (db.connect()) {
                    db.initAllTables()
                    db.loadCertificates()
                } else {
                    dolog(L_INFO, "MySQL unavailable, using cert.txt only")
                }
                gMysql = db
            case None => dolog(L_INFO, "No [database] config, using cert.txt only")
        }; case None => () }
        // 读取轨迹开关
        match (configMan) { case Some(cm) => match (cm.getGroup("trails")) {
            case Some(g) => match (g.getEntry("enabled")) {
                case Some(e) => this.trailEnabled = (e.getData() == "true" || e.getData() == "1")
                case None => ()
            }
            case None => ()
        }; case None => () }
    }

    public func initHttpApi(): Unit {
        match (configMan) { case Some(cm) => match (cm.getGroup("httpapi")) {
            case Some(g) =>
                let en = match (g.getEntry("enabled")) { case Some(e) => e.getData() == "true" || e.getData() == "1"; case None => false }
                let ap: Int32 = match (g.getEntry("port")) { case Some(e) =>
                    let v = e.getInt()
                    if (v < 1 || v > 65535) { dolog(L_WARNING, "Invalid httpapi port ${v}, using default ${DEFAULT_HTTP_API_PORT}"); DEFAULT_HTTP_API_PORT }
                    else { v }
                case None => DEFAULT_HTTP_API_PORT }
                let ak = match (g.getEntry("key")) { case Some(e) => e.getData(); case None => "" }
                if (en) { let api = HttpApi(ap, ak); api.start(); dolog(L_INFO, "HTTP API on port ${ap}" + if (ak != "") { " (key protected)" } else { " (no auth!)" }) }
            case None => ()
        }; case None => () }
    }

    public func createInterfaces(): Unit {
        clientInterface = ClInterface(this.clientPort, "client", "client interface")
        serverInterface = ServInterface(this.serverPort, "server", "server interface")
        systemInterface = SysInterface(this.systemPort, "system", "system management interface")
        systemInterface?.setPrompt("${myServer?.ident ?? "FSD"}> ") 
        clientInterface?.setFlood(50000); clientInterface?.setOutBufLimit(100000)
        clientInterface?.start(); serverInterface?.start(); systemInterface?.start()
        // 启动时清理 whazzup 旧数据，初始化轨迹日志文件
        writeWhazzUp()
    }

    public func makeConnections(): Unit {
        match (configMan) { case Some(cm) => match (cm.getGroup("connections")) {
            case Some(g) =>
                // 读 allowfrom IP 白名单
                match (g.getEntry("allowfrom")) {
                    case Some(e) => for (i in 0..e.getNparts()) {
                        let ip = e.getPart(i).trim()
                        if (ip != "") {
                            clientInterface?.allow(ip)
                            serverInterface?.allow(ip)
                        }
                    }; case None => ()
                }
                // 读 connectto 服务器连接
                match (g.getEntry("connectto")) {
                    case Some(e) => for (i in 0..e.getNparts()) {
                        var h = e.getPart(i); var cp: Int32 = 3011
                        match (h.indexOf(r':')) { case Some(pos) => cp = parseInt32(substrFrom(h, pos + 1)); h = substrTo(h, pos); case None => () }
                        serverInterface?.addUser(h, cp, None)
                    }
                    case None => ()
                }
            case None => ()
        }; case None => () }
        serverInterface?.sendReset()
    }

    public func readCert(): Unit {
        match (this.certFile) {
            case Some(path) =>
                try {
                    let bytes = File.readFrom(Path(path))
                    let content = String.fromUtf8(bytes)
                    var cert = rootCert
                    while (true) { match (cert) { case Some(c) => c.livecheck = 0; cert = c.next; case None => break } }
                    dolog(L_INFO, "Reading certs from ${path}")
                    for (line in splitStr(content, "\n")) { handleCertLine(line) }
                    cert = rootCert
                    while (true) { match (cert) { case Some(c) => let nx = c.next
                        if (c.livecheck == 0) { serverInterface?.sendCert("*", CERT_DELETE, c, None); removeCert(c) }
                        cert = nx
                    ; case None => break }}
                } catch (e: Exception) {
                    dolog(L_WARNING, "Certificate file ${path} not found")
                }
            case None => ()
        }
    }

    public func handleCertLine(line: String): Unit {
        let t = line.trim()
        if (t == "" || (t.toRuneArray().size > 0 && (t.toRuneArray()[0] == r';' || t.toRuneArray()[0] == r'#'))) { return }
        let parts = splitStr(t, " ")
        if (parts.size < 3) { return }
        let cid = parts[0]; let pwd = parts[1]; let level = parseInt32(parts[2])
        match (getCert(cid)) {
            case Some(c) => c.livecheck = 1
                if (c.password != pwd || c.level != level) { c.configure(pwd, level, mgmtime(), myServer?.ident ?? "local"); serverInterface?.sendCert("*", CERT_MODIFY, c, None) }
            case None => let cert = Certificate(cid, pwd, level, mgmtime(), myServer?.ident ?? "local"); addCert(cert); serverInterface?.sendCert("*", CERT_ADD, cert, None)
        }
    }

    public func run(): Int32 {
        configMan?.run()
        match (configMan) { case Some(cm) => match (cm.getGroup("system")) {
            case Some(g) =>
                let bf = g.getEntry("blocked_flights")?.getData() ?? ""
                synchronized(blockedLock) { blockedFlights = bf }
            case None => ()
        }; case None => () }
        let now = mgmtime()
        if (now != this.timer) { this.timer = now; doChecks() }
        clientInterface?.run(); serverInterface?.run(); systemInterface?.run()
        return 0
    }

    public func doChecks(): Unit {
        let now = mgmtime()
        if ((now - this.prevNotify) > NOTIFYCHECK) { match (myServer) { case Some(s) => serverInterface?.sendServerNotify("*", s, None); case None => () }; this.prevNotify = now }
        if ((now - this.prevLagCheck) > LAGCHECK) { serverInterface?.sendPing("*", "-1 ${now}"); this.prevLagCheck = now }
        if ((now - this.prevCertCheck) > CERTFILECHECK) { readCert(); this.prevCertCheck = now }
        if (this.whazzupDirty || (now - this.prevWhazzup) >= WHAZZUPCHECK) { writeWhazzUp(); this.prevWhazzup = now }
        if ((now - this.prevHeartbeat) >= 3600) {
            this.prevHeartbeat = now
            let cc = clientCount()
            match (myServer) {
                case Some(s) =>
                    // 对 hostname 做简单净化防止 URL 注入
                    let safeHost = s.hostname.replace("&", "").replace("#", "").replace("?", "").replace(" ", "")
                    let url = "https://system.ldpfly.cn/api/fsd_ping.php?host=${safeHost}&clients=${cc}"
                    try {
                        let (code, _, _) = executeWithOutput("curl", ["-s", "--connect-timeout", "5", "--max-time", "10", url])
                        if (code != 0) { dolog(L_WARNING, "Heartbeat failed: ${code}") }
                    } catch (e: Exception) { dolog(L_WARNING, "Heartbeat error: ${e}") }
                case None => ()
            }
        }
        // MySQL keepalive — 每 60 秒健康检查一次，检测真实断线并防空闲断线
        if ((now - this.prevDbCheck) >= 60) {
            this.prevDbCheck = now
            match (gMysql) { case Some(db) => db.checkAlive(); db.ensureConnected(); case None => () }
        }
        // Wind Delta — 每 70 秒广播随机风变化（合并为单条消息减少流量）
        if ((now - this.prevWindDelta) >= WINDDELTATIMEOUT) {
            this.prevWindDelta = now
            let ts = sprintGmt(now)
            var windMsg = StringBuilder()
            let _keys = getClientKeys()
            for (_i in 0.._keys.size) {
                let c = match (clientMap.get(_keys[_i])) { case Some(x) => x; case None => continue }
                let wd = randInt(360)
                let ws = randInt(50)
                let wg = if (randInt(10) > 3) { randInt(30) } else { 0 }
                windMsg.append("#DL${c.callsign}:${ts}:${wd}:${ws}:${wg}\r\n")
            }
            clientInterface?.broadcastToAll(windMsg.toString())
        }
        // 飞行记录刷盘：必须用「追加写」。
        // 旧写法每次读取整个 replay 文件、拼接后再整体写回，文件随时间增长会变成平方级开销，
        // 且占用主循环与 replayLock，导致跑久了整体变慢、whazzup 写入也变慢。
        replayLock.lock()
        if (replayBuf != "") {
            let dateStr = sprintGmtDate(mgmtime())
            try {
                File.appendTo(Path("replay_${dateStr}.txt"), replayBuf.toArray())
                replayBuf = ""
            } catch (_: Exception) {}
        }
        replayLock.unlock()
        // 飞行轨迹保存（每 3 秒） + 断线清理（每 30 秒）
        if (this.trailEnabled && (now - this.prevTrailSave >= 3)) {
            this.prevTrailSave = now
            dolog(L_DEBUG, "Trail: enabled=${this.trailEnabled} mysql=${match (gMysql) { case Some(db) => db.isConnected(); case None => false }}")
            match (gMysql) {
                case Some(db) =>
                    if (db.ensureConnected()) {
                        let _keys = getClientKeys()
                        var saved = 0
                        var activeCallsigns = HashSet<String>()
                        for (_i in 0.._keys.size) {
                            if (let Some(c) <- clientMap.get(_keys[_i])) {
                            dolog(L_DEBUG, "Trail pilot: ${c.callsign} lat=${c.lat} lon=${c.lon} alt=${c.altitude}")
                            if (c.isPilot() && c.lat != 0.0 && c.lon != 0.0) {
                                db.saveFlightTrail(c.callsign, c.lat, c.lon, c.altitude, c.groundspeed, Int32(c.headingCalc))
                                saved += 1
                                activeCallsigns.add(c.callsign)
                            }
                            }
                        }
                        dolog(L_DEBUG, "Trail: ${saved} positions written for ${_keys.size} clients")
                        if (now % 30 == 0) { db.cleanFlightTrails(activeCallsigns, Int32(now / 1000)) }
} else { dolog(L_INFO, "Trail: MySQL not connected") }
                case None => dolog(L_INFO, "Trail: gMysql is None")
            }
        }
        checkServerTimeouts(now); checkClientTimeouts(now)
        // 接口连接表清理（防御）：每 30 秒回收长时间无数据的连接，
        // 避免任何残留导致 users 列表膨胀、accept 停摆。
        if ((now - this.prevUserCheck) >= 30) {
            this.prevUserCheck = now
            let idle = USERTIMEOUT
            clientInterface?.checkTimeouts(idle)
            serverInterface?.checkTimeouts(idle)
            systemInterface?.checkTimeouts(idle)
        }
    }

    public func checkServerTimeouts(now: Int64): Unit {
        var cur = rootServer
        while (true) { match (cur) { case Some(sv) => let nx = sv.next
            if (!svMy(sv) && (now - sv.alive) > SERVERTIMEOUT) { dolog(L_INFO, "Svr timeout: ${sv.ident}"); removeServer(sv) }; cur = nx
        ; case None => break }}
    }

    public func checkClientTimeouts(now: Int64): Unit {
        let isSilent = match (myServer) { case Some(s) => s.isSilent(); case None => false }
        let limit = if (isSilent) { SILENTCLIENTTIMEOUT } else { CLIENTTIMEOUT }
        var toRemove = ArrayList<String>()
        let _keys = getClientKeys()
        for (_i in 0.._keys.size) {
            let cl = match (clientMap.get(_keys[_i])) { case Some(x) => x; case None => continue }
            if (!clLocal(cl) && (now - cl.alive) > limit) {
                dolog(L_INFO, "Cli timeout: ${cl.callsign}")
                toRemove.add(cl.callsign.toUpper())
            }
        }
        for (cs in toRemove) {
            match (clientMap.get(cs)) {
                case Some(c) => removeClient(c)
                case None => ()
            }
        }
    }

    public func markWhazzupDirty(): Unit { this.whazzupDirty = true }

    public func writeWhazzUp(): Unit {
        this.whazzupDirty = false
        match (this.whazzupFile) {
            case Some(path) =>
                let now = mgmtime()
                var wz = StringBuilder()
                wz.append("![DateStamp]${sprintGmtDate(now)}\n")
                wz.append("!GENERAL\n")
                wz.append("VERSION = 1\n")
                wz.append("RELOAD = 1\n")
                wz.append("UPDATE = ${sprintGmt(now)}\n")
                let clCount = clientCount(); let svCount = serverCount()
                wz.append("CONNECTED CLIENTS = ${clCount}\n")
                wz.append("CONNECTED SERVERS = ${svCount}\n")
                wz.append("!CLIENTS\n")
                let _keys = getClientKeys()
                for (_i in 0.._keys.size) {
                    let c = match (clientMap.get(_keys[_i])) { case Some(x) => x; case None => continue }
                    // dataseg1: callsign:cid:realname:type
                    wz.append("${c.callsign}:${c.cid}:${c.realname}:${if (c.isAtc()) {"ATC"} else {"PILOT"}}")
                    // dataseg2: frequency (ATC only, format: :1xx.xxx)
                    if (c.frequency != 0 && c.frequency < 100000) {
                        let mhz = c.frequency / 1000; let khz = c.frequency % 1000
                        let mhzStr = if (mhz < 10) { "0${mhz}" } else { "${mhz}" }
                        let khzStr = if (khz < 100) { if (khz < 10) { "00${khz}" } else { "0${khz}" } } else { "${khz}" }
                        wz.append(":1${mhzStr}.${khzStr}")
                    } else { wz.append(":") }
                    // dataseg3: lat:lon:altitude:groundspeed
                    if (c.lat != 0.0 && c.altitude < 100000 && c.lon != 0.0) {
                        wz.append(":${c.lat}:${c.lon}:${c.altitude}:${c.groundspeed}")
                    } else { wz.append(":::") }
                    // dataseg4: flightplan basics
                    match (c.plan) {
                        case Some(fp) => wz.append(":${fp.aircraft}:${fp.tascruise}:${fp.depAirport}:${fp.altitude}:${fp.destAirport}")
                        case None => wz.append(":::::")
                    }
                    // dataseg5: server:protocol:rating:transponder:facilitytype:visualrange
                    let svIdent = match (c.location) { case Some(s) => s.ident; case None => "" }
                    wz.append(":${svIdent}:${c.protocol}:${c.rating}:${c.transponder}:${c.facilitytype}:${c.visualrange}")
                    // dataseg6: flightplan details
                    match (c.plan) {
                        case Some(fp) =>
                            let fpType = fp.`type`
                            wz.append(":${fp.revision}:${fpType}:${fp.depTime}:${fp.actDepTime}:${fp.hrsEnroute}:${fp.minEnroute}:${fp.hrsFuel}:${fp.minFuel}:${fp.altAirport}:${fp.remarks}:${fp.route}")
                        case None => wz.append(":::::::::::")
                    }
                    // dataseg7: starttime:heading(从位置计算)
                    wz.append("::::::${sprintGmt(c.startTime)}:HDG${Int64(c.headingCalc)}\n")
                }
                wz.append("!SERVERS\n")
                var sv = rootServer
                while (true) { match (sv) { case Some(srv) =>
                    if (srv.hostname != "n/a") { wz.append("${srv.ident}:${srv.hostname}:${srv.location}:${srv.name}:${if ((srv.flags & SERVER_SILENT) != 0) {0} else {1}}\n") }; sv = srv.next
                ; case None => break }}
                File.writeTo(Path(path), wz.toString().toArray())
            case None => ()
        }
    }

    public func stop(): Unit { clientInterface?.stop(); serverInterface?.stop(); systemInterface?.stop(); dolog(L_INFO, "FSD stopped") }

    // 优雅停机：先通知所有客户端断开（$!!，客户端会识别并自行离开），冲刷后停接口
    public func gracefulShutdown(): Unit {
        dolog(L_INFO, "Graceful shutdown: notifying all clients")
        // 先发可见文本，再发 $!! 并优雅关闭（保证两者都送达）
        clientInterface?.broadcastToAll("#TMserver:*:FSD server is restarting, please reconnect shortly\r\n")
        clientInterface?.notifyAllShutdown("Server restarting, please reconnect")
        sleep(1500 * Duration.millisecond)
        this.stop()
    }
}

func gStr(group: ConfigGroup, key: String, def: String): String { match (group.getEntry(key)) { case Some(e) => e.getData(); case None => def } }
func gPort(group: ConfigGroup, key: String, def: Int32): Int32 {
    match (group.getEntry(key)) {
        case Some(e) =>
            let v = e.getInt()
            if (v < 1 || v > 65535) { dolog(L_WARNING, "Invalid port ${v} for ${key}, using default ${def}"); return def }
            return v
        case None => return def
    }
}
func dbOk(): Bool { match (gMysql) { case Some(db) => db.isConnected(); case None => false } }
func svMy(sv: Server): Bool { match (myServer) { case Some(m) => sv.ident == m.ident; case None => false } }
func clLocal(cl: Client): Bool { match (cl.location) { case Some(loc) => loc.ident == (myServer?.ident ?? ""); case None => false } }
