package FSD_Cangjie

import std.fs.*
import std.process.*

var clientInterface: ?ClInterface = None
var serverInterface: ?ServInterface = None
var systemInterface: ?SysInterface = None
var configMan: ?ConfigManager = None
var metarManager: ?MetarManager = None
var fsdEngine: ?FsdEngine = None

public class FsdEngine {
    var certFile: ?String; var whazzupFile: ?String
    var prevNotify: Int64; var prevLagCheck: Int64; var prevCertCheck: Int64; var prevWhazzup: Int64
    var prevHeartbeat: Int64
    var prevWindDelta: Int64
    var timer: Int64; var clientPort: Int32; var serverPort: Int32; var systemPort: Int32

    public init(configFile: String) {
        this.certFile = None; this.whazzupFile = None
        this.prevNotify = 0; this.prevLagCheck = 0; this.prevCertCheck = 0; this.prevWhazzup = 0
        this.prevHeartbeat = 0
        this.prevWindDelta = 0
        this.timer = 0; this.clientPort = DEFAULT_CLIENT_PORT
        this.serverPort = DEFAULT_SERVER_PORT; this.systemPort = DEFAULT_SYSTEM_PORT

        dolog(L_INFO, "Booting FSD server v${VERSION}")
        configMan = ConfigManager(configFile); metarManager = MetarManager()
        configure(); initDatabase(); initHttpApi(); createInterfaces(); makeConnections()
        dolog(L_INFO, "FSD server is up and running")
        this.prevNotify = mgmtime(); this.prevLagCheck = mgmtime()
        this.timer = mgmtime(); this.prevWhazzup = mgmtime()
        this.prevHeartbeat = mgmtime()
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
            case None => ()
        }; case None => () }
        configMyServer()
        readCert()
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
                    db.loadCertificates()
                } else {
                    dolog(L_INFO, "MySQL unavailable, using cert.txt only")
                }
                gMysql = db
            case None => dolog(L_INFO, "No [database] config, using cert.txt only")
        }; case None => () }
    }

    public func initHttpApi(): Unit {
        match (configMan) { case Some(cm) => match (cm.getGroup("httpapi")) {
            case Some(g) =>
                let en = match (g.getEntry("enabled")) { case Some(e) => e.getData() == "true" || e.getData() == "1"; case None => false }
                let ap: Int32 = match (g.getEntry("port")) { case Some(e) => e.getInt(); case None => DEFAULT_HTTP_API_PORT }
                if (en) { let api = HttpApi(ap); api.start(); dolog(L_INFO, "HTTP API on port ${ap}") }
            case None => ()
        }; case None => () }
    }

    public func createInterfaces(): Unit {
        clientInterface = ClInterface(this.clientPort, "client", "client interface")
        serverInterface = ServInterface(this.serverPort, "server", "server interface")
        systemInterface = SysInterface(this.systemPort, "system", "system management interface")
        systemInterface?.setPrompt("${myServer?.ident ?? "FSD"}> ") 
        clientInterface?.setFlood(100000); clientInterface?.setOutBufLimit(100000)
        clientInterface?.start(); serverInterface?.start(); systemInterface?.start()
    }

    public func makeConnections(): Unit {
        match (configMan) { case Some(cm) => match (cm.getGroup("connections")) {
            case Some(g) => match (g.getEntry("connectto")) {
                case Some(e) => for (i in 0..e.getNparts()) {
                    var h = e.getPart(i); var cp: Int32 = 3011
                    match (h.indexOf(r':')) { case Some(pos) => cp = parseInt32(substrFrom(h, pos + 1)); h = substrTo(h, pos); case None => () }
                    serverInterface?.addUser(h, cp, None)
                }
                case None => ()
            }; case None => ()
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
        configMan?.run(); let now = mgmtime()
        if (now != this.timer) { this.timer = now; doChecks() }
        clientInterface?.run(); serverInterface?.run(); systemInterface?.run()
        return 0
    }

    public func doChecks(): Unit {
        let now = mgmtime()
        if ((now - this.prevNotify) > NOTIFYCHECK) { match (myServer) { case Some(s) => serverInterface?.sendServerNotify("*", s, None); case None => () }; this.prevNotify = now }
        if ((now - this.prevLagCheck) > LAGCHECK) { serverInterface?.sendPing("*", "-1 ${now}"); this.prevLagCheck = now }
        if ((now - this.prevCertCheck) > CERTFILECHECK) { readCert(); this.prevCertCheck = now }
        if ((now - this.prevWhazzup) >= WHAZZUPCHECK) { writeWhazzUp(); this.prevWhazzup = now }
        if ((now - this.prevHeartbeat) >= 3600) {
            this.prevHeartbeat = now
            var clientCount: Int64 = 0
            var cur = rootClient
            while (true) { match (cur) { case Some(c) => clientCount += 1; cur = c.next; case None => break } }
            match (myServer) {
                case Some(s) =>
                    let url = "https://system.ldpfly.cn/api/fsd_ping.php?host=${s.hostname}&clients=${clientCount}"
                    try {
                        let (code, _, _) = executeWithOutput("curl", ["-s", "--connect-timeout", "5", "--max-time", "10", url])
                        if (code != 0) { dolog(L_WARNING, "Heartbeat failed: ${code}") }
                    } catch (e: Exception) { dolog(L_WARNING, "Heartbeat error: ${e}") }
                case None => ()
            }
        }
        // Wind Delta — 每 70 秒广播随机风变化
        if ((now - this.prevWindDelta) >= WINDDELTATIMEOUT) {
            this.prevWindDelta = now
            let ts = sprintGmt(now)
            // 为每个在线客户端生成随机风数据
            var cl = rootClient
            while (true) { match (cl) {
                case Some(c) =>
                    let wd = randInt(360)
                    let ws = randInt(50)
                    let wg = if (randInt(10) > 3) { randInt(30) } else { 0 }
                    let msg = "#DL${c.callsign}:${ts}:${wd}:${ws}:${wg}\r\n"
                    clientInterface?.broadcastToAll(msg)
                    cl = c.next
                case None => break
            }}
        }
        checkServerTimeouts(now); checkClientTimeouts(now)
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
        var cur = rootClient
        while (true) { match (cur) { case Some(cl) => let nx = cl.next
            if (!clLocal(cl) && (now - cl.alive) > limit) { dolog(L_INFO, "Cli timeout: ${cl.callsign}"); removeClient(cl) }; cur = nx
        ; case None => break }}
    }

    public func writeWhazzUp(): Unit {
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
                var cl = rootClient
                while (true) { match (cl) { case Some(c) =>
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
                    // dataseg7: starttime:pbh
                    wz.append("::::::${sprintGmt(c.startTime)}:${c.pbh}\n")
                    cl = c.next
                ; case None => break }}
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
}

func gStr(group: ConfigGroup, key: String, def: String): String { match (group.getEntry(key)) { case Some(e) => e.getData(); case None => def } }
func gPort(group: ConfigGroup, key: String, def: Int32): Int32 { match (group.getEntry(key)) { case Some(e) => e.getInt(); case None => def } }
func dbOk(): Bool { match (gMysql) { case Some(db) => db.isConnected(); case None => false } }
func svMy(sv: Server): Bool { match (myServer) { case Some(m) => sv.ident == m.ident; case None => false } }
func clLocal(cl: Client): Bool { match (cl.location) { case Some(loc) => loc.ident == (myServer?.ident ?? ""); case None => false } }
