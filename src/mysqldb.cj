package FSD_Cangjie

import mysql
import std.collection.*
import std.net.*
import std.process.*

var gMysql: ?MysqlDB = None

func bcryptVerify(pwd: String, hash: String): Bool {
    if (!hash.startsWith("\$2")) { return pwd == hash }
    // 直接调 PHP 验证 bcrypt（参数传 argv 避免注入）
    try {
        // 密码/散列改走环境变量，避免出现在进程 argv（ps 可见）
        let env = HashMap<String, String>()
        env["FSD_PW"] = pwd
        env["FSD_H"] = hash
        let (code, stdoutBytes, _) = executeWithOutput("php", ["-r",
            "echo password_verify(getenv('FSD_PW'), getenv('FSD_H')) ? '1' : '0';"],
            environment: env)
        if (code == 0) {
            let result = String.fromUtf8(stdoutBytes).trim()
            return result == "1"
        }
    } catch (e: Exception) {}
    return pwd == hash
}

public class MysqlDB {
    var host: String; var user: String; var password: String
    var database: String; var port: Int32
    var tableUsers: String; var tableFps: String
    // 可配置的字段名
    var colUserCallsign: String; var colUserPwd: String; var colUserPerm: String
    var colFpCallsign: String; var colFpCid: String; var colFpData: String
    var conn: ?mysql.Connection; var useMysql: Bool
    var driver: ?mysql.Driver = None
    var ds: ?mysql.Datasource = None
    var connBroken: Bool = false
    var authFailed: Bool = false   // 认证失败：配置错误，重启前不再尝试，避免连接池空转泄漏 FD
    var lastConnectAttempt: Int64 = 0
    var lastTrailWarn: Int64 = 0
    // 连接池上限：驱动默认 1000，远超 MySQL max_connections(默认151)。
    // 并发登录/断线时会瞬间新建大量连接，触发 1040 Too many connections。
    var poolMaxCount: Int64 = 8

    public init(host: String, user: String, password: String, database: String, port: Int32,
                tableUsers: String, tableFps: String,
                colUserCallsign: String, colUserPwd: String, colUserPerm: String,
                colFpCallsign: String, colFpCid: String, colFpData: String) {
        this.host = host; this.user = user; this.password = password
        this.database = database; this.port = port
        this.tableUsers = tableUsers; this.tableFps = tableFps
        this.colUserCallsign = colUserCallsign; this.colUserPwd = colUserPwd; this.colUserPerm = colUserPerm
        this.colFpCallsign = colFpCallsign; this.colFpCid = colFpCid; this.colFpData = colFpData
        this.conn = None; this.useMysql = false
    }

    public func isConnected(): Bool { return this.useMysql }

    // mysql.Driver() 只创建一次（重复调用会抛 Duplicate database driver）
    private func getDriver(): mysql.Driver {
        match (this.driver) {
            case Some(d) => return d
            case None => let d = mysql.Driver(); this.driver = d; return d
        }
    }

    // 检查连接并尝试重连（长连接 MySQL 可能断开）
    // 注意：只在连接级错误时才重连，且带 30 秒退避，避免重连风暴
    public func ensureConnected(): Bool {
        if (this.authFailed) { return false }
        if (!this.useMysql || this.connBroken) {
            if (mgmtime() - this.lastConnectAttempt < 30) { return false }
            return this.reconnect()
        }
        match (this.conn) { case Some(_) => return true; case None => return this.reconnect() }
    }

    private func reconnect(): Bool {
        if (this.authFailed) { return false }
        this.lastConnectAttempt = mgmtime()
        this.closeDs()
        var newDs: ?mysql.Datasource = None
        try {
            let dsn = "${this.user}:${this.password}@tcp(${this.host}:${this.port})/${this.database}"
            let d = this.getDriver().open(dsn, [("poolMaxCount", this.poolMaxCount.toString())])
            newDs = Some(d)
            let c = d.connect()
            c.query("SELECT 1")   // 立即校验认证，避免连接池空转泄漏
            this.conn = c
            this.ds = Some(d)
            this.useMysql = true
            this.connBroken = false
            dolog(L_INFO, "MySQL: Reconnected successfully")
            return true
        } catch (e: Exception) {
            match (newDs) { case Some(d) => try { d.close() } catch (_: Exception) {}; case None => () }
            this.ds = None; this.conn = None; this.useMysql = false; this.connBroken = true
            if (this.isAuthError(e)) { this.authFailed = true; dolog(L_ERR, "MySQL: 认证/配置错误，已停用数据库直到重启 — ${e}") }
            else { dolog(L_WARNING, "MySQL: Reconnect failed — ${e}") }
            return false
        }
    }

    // 只有真正的 I/O 层异常才算连接断开；SqlException / OverflowException 等逻辑错误不应触发重连
    // （重连会新建连接池并遗弃旧池连接，导致 MySQL 连接数缓慢增长）
    private func isServerError(e: Exception): Bool {
        return !this.isConnError(e)
    }

    private func isConnError(e: Exception): Bool {
        let m = e.toString().toAsciiLower()
        if (m.contains("ioexception")) { return true }
        if (m.contains("socketexception")) { return true }
        if (m.contains("broken pipe")) { return true }
        if (m.contains("connection reset")) { return true }
        if (m.contains("connection refused")) { return true }
        if (m.contains("eof")) { return true }
        if (m.contains("failed to write")) { return true }
        if (m.contains("failed to read")) { return true }
        if (m.contains("socket is closed")) { return true }
        if (m.contains("读取信息")) { return true }
        return false
    }

    // 认证/库不存在等配置类错误：重试无意义，应停用 DB
    private func isAuthError(e: Exception): Bool {
        let m = e.toString().toAsciiLower()
        return m.contains("access denied") || m.contains("1045") || m.contains("1044") || m.contains("unknown database") || m.contains("1049")
    }

    // 关闭数据源（含连接池），释放其持有的一切 socket，避免 CLOSE-WAIT 泄漏
    private func closeDs(): Unit {
        match (this.ds) {
            case Some(d) => try { d.close() } catch (_: Exception) {}
            case None => ()
        }
        this.ds = None
        this.conn = None
    }

    // 统一处理 DB 错误：任何错误都先关闭数据源释放 socket，避免连接池空转把 FD 漏光；
    // 认证错误直接停用 DB（配置错误重试无意义）。
    private func handleDbError(e: Exception): Unit {
        if (this.isAuthError(e)) {
            this.authFailed = true
            this.closeDs()
            this.useMysql = false; this.connBroken = true
            dolog(L_ERR, "MySQL: 认证/配置错误，已停用数据库直到重启 — ${e}")
        } else {
            this.closeDs()
            this.markConnBroken()
        }
    }

    // 定时健康检查：检测真实连接断开（如 MySQL 重启）。只有 I/O 异常才标记断连。
    public func checkAlive(): Unit {
        if (!this.useMysql || this.authFailed) { return }
        match (this.conn) {
            case Some(db) =>
                try {
                    db.query("SELECT 1")
                } catch (e: Exception) {
                    this.handleDbError(e)
                }
            case None => ()
        }
    }

    private func markConnBroken(): Unit {
        this.connBroken = true
        this.useMysql = false
    }

    public func connect(): Bool {
        if (this.authFailed) { return false }
        dolog(L_INFO, "MySQL: Connecting to ${this.database}@${this.host}:${this.port}")
        var newDs: ?mysql.Datasource = None
        try {
            let dsn = "${this.user}:${this.password}@tcp(${this.host}:${this.port})/${this.database}"
            let d = this.getDriver().open(dsn, [("poolMaxCount", this.poolMaxCount.toString())])
            newDs = Some(d)
            let c = d.connect()
            c.query("SELECT 1")   // 立即校验认证，避免连接池空转泄漏
            this.conn = c
            this.ds = Some(d)
            this.useMysql = true
            this.connBroken = false
            this.lastConnectAttempt = mgmtime()
            dolog(L_INFO, "MySQL: Connected successfully")
            this.initTables()
            return true
        } catch (e: Exception) {
            match (newDs) { case Some(d) => try { d.close() } catch (_: Exception) {}; case None => () }
            this.ds = None; this.conn = None; this.useMysql = false; this.connBroken = true
            if (this.isAuthError(e)) { this.authFailed = true; dolog(L_ERR, "MySQL: 认证/配置错误，已停用数据库直到重启 — ${e}") }
            else { dolog(L_WARNING, "MySQL: Connection failed, fallback to cert.txt — ${e}") }
            return false
        }
    }

    private func initTables(): Unit {
        match (this.conn) {
            case Some(db) =>
                // 用户认证表（必须）
                try {
                    db.update("CREATE TABLE IF NOT EXISTS ${this.tableUsers} (${this.colUserCallsign} VARCHAR(12) PRIMARY KEY, ${this.colUserPwd} VARCHAR(255) NOT NULL, ${this.colUserPerm} INT NOT NULL DEFAULT 1, registration_time DATETIME DEFAULT CURRENT_TIMESTAMP, last_login_time DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)")
                    dolog(L_INFO, "MySQL: Users table ready (${this.tableUsers})")
                } catch (e: Exception) {
                    dolog(L_WARNING, "MySQL: Users table init failed, disconnecting — ${e}")
                    this.handleDbError(e)
                    return
                }
                // 飞行计划表（可选，失败不影响认证）
                try {
                    db.update("CREATE TABLE IF NOT EXISTS ${this.tableFps} (${this.colFpCallsign} VARCHAR(12) PRIMARY KEY, ${this.colFpCid} VARCHAR(32) NOT NULL, ${this.colFpData} TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP)")
                    dolog(L_INFO, "MySQL: Flight plans table ready (${this.tableFps})")
                } catch (e: Exception) {
                    dolog(L_WARNING, "MySQL: Flight plans table init failed, flight plan feature disabled — ${e}")
                }
            case None => ()
        }
    }

    private func initTrailTable(): Unit {
        match (this.conn) {
            case Some(db) =>
                try {
                    db.update("CREATE TABLE IF NOT EXISTS flight_trails (id INT AUTO_INCREMENT PRIMARY KEY, callsign VARCHAR(12) NOT NULL, lat DOUBLE NOT NULL, lon DOUBLE NOT NULL, altitude INT NOT NULL, speed INT NOT NULL, heading INT NOT NULL DEFAULT 0, ts BIGINT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, INDEX idx_cs (callsign), INDEX idx_ts (ts))")
                } catch (e: Exception) {
                    this.handleDbError(e)
                    dolog(L_WARNING, "MySQL: flight_trails table init failed — ${e}")
                }
            case None => ()
        }
    }

    public func initAllTables(): Unit {
        this.initTables()
        this.initTrailTable()
    }

    public func saveFlightTrail(callsign: String, lat: Float64, lon: Float64, altitude: Int32, speed: Int32, heading: Int32): Bool {
        if (!this.ensureConnected()) { return false }
        match (this.conn) {
            case Some(db) =>
                try {
                    db.update("INSERT INTO flight_trails (callsign, lat, lon, altitude, speed, heading, ts) VALUES (?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP())", callsign, lat.toString(), lon.toString(), altitude.toString(), speed.toString(), heading.toString())
                    return true
                } catch (e: Exception) {
                    if (mgmtime() - this.lastTrailWarn >= 10) {
                        this.lastTrailWarn = mgmtime()
                        dolog(L_WARNING, "MySQL: saveFlightTrail failed — ${e}")
                    }
                    this.handleDbError(e)
                    return false
                }
            case None => return false
        }
    }

    // 清理断线飞机的过期轨迹
    public func cleanFlightTrails(activeCallsigns: HashSet<String>, now: Int32): Unit {
        match (this.conn) {
            case Some(db) =>
                try {
                    // 删除超过 1 小时的轨迹
                    db.update("DELETE FROM flight_trails WHERE ts < ?", now - 3600)
                    // 删除不在当前在线列表且超过 5 分钟无更新的轨迹
                    var csStr = ""
                    for (k in activeCallsigns) {
                        if (csStr != "") { csStr += "','" }
                        // 防 SQL 注入：转义反斜杠与单引号（呼号本应只含字母数字，但此处不信任输入）
                        csStr += k.replace("\\", "\\\\").replace("'", "''")
                    }
                    if (csStr != "") {
                        db.update("DELETE FROM flight_trails WHERE ts < ? AND callsign NOT IN ('${csStr}')", now - 300)
                    }
                } catch (e: Exception) {
                    dolog(L_WARNING, "MySQL: cleanFlightTrails failed — ${e}")
                    this.handleDbError(e)
                }
            case None => ()
        }
    }

    // 断线时立即删除该用户的所有轨迹
    public func deleteFlightTrails(callsign: String): Unit {
        if (!this.ensureConnected()) { return }
        match (this.conn) {
            case Some(db) =>
                try { db.update("DELETE FROM flight_trails WHERE callsign=?", callsign) }
                catch (e: Exception) { dolog(L_WARNING, "MySQL: deleteFlightTrails failed — ${e}"); this.handleDbError(e) }
            case None => ()
        }
    }

    public func disconnect(): Unit { this.closeDs(); this.useMysql = false; this.connBroken = true }

    public func loadCertificates(): Bool {
        match (this.conn) {
            case Some(db) =>
                try {
                    let sql = "SELECT ${this.colUserCallsign}, ${this.colUserPwd}, ${this.colUserPerm} FROM ${this.tableUsers}"
                    let rows = db.query(sql)
                    markAllCertsInactive()
                    for (row in rows) {
                        let cs = row.getString(this.colUserCallsign)
                        let pw = row.getString(this.colUserPwd)
                        let lv = row.getInt(this.colUserPerm)
                        if (let Some(c) <- cs && let Some(p) <- pw && let Some(l) <- lv) {
                            match (getCert(c)) {
                                case Some(existing) => existing.configure(p, Int32(l), mgmtime(), "mysql")
                                case None =>
                                    let cert2 = Certificate(c, p, Int32(l), mgmtime(), "mysql")
                                    addCert(cert2)
                            }
                        }
                    }
                    removeInactiveCerts()
                    dolog(L_INFO, "MySQL: Certificates loaded from ${this.tableUsers}")
                    return true
                } catch (e: Exception) {
                    dolog(L_WARNING, "MySQL: loadCertificates failed — ${e}"); this.handleDbError(e); return false
                }
            case None => return false
        }
    }

    public func verifyCertificate(cid: String, pwd: String): (Bool, Int32) {
        // 优先 MySQL
        match (this.conn) {
            case Some(db) =>
                match (certRow(cid, pwd)) {
                    case (true, level) => return (true, level)
                    case _ => ()
                }
            case None => ()
        }
        // 回退 cert.txt (内存中，包含从 MySQL 加载的 bcrypt 密码)
        match (getCert(cid)) {
            case Some(c) =>
                if (bcryptVerify(pwd, c.password)) {
                    if (c.level <= LEV_SUSPENDED) { return (false, LEV_SUSPENDED) }
                    // 同步到 MySQL
                    match (this.conn) {
                        case Some(db) =>
                            try { db.update("INSERT INTO ${this.tableUsers} (${this.colUserCallsign}, ${this.colUserPwd}, ${this.colUserPerm}) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE last_login_time=NOW()", cid, c.password, c.level) } catch (e: Exception) {}
                        case None => ()
                    }
                    return (true, c.level)
                }
                return (false, LEV_OBSPILOT)
            case None => return (false, LEV_OBSPILOT)
        }
    }

    private func certRow(cid: String, pwd: String): (Bool, Int32) {
        match (this.conn) {
            case Some(db) =>
                try {
                    let sql = "SELECT ${this.colUserPwd}, ${this.colUserPerm} FROM ${this.tableUsers} WHERE ${this.colUserCallsign}=? LIMIT 1"
                    let rows = db.query(sql, cid)
                    if (rows.size == 0) { return (false, LEV_OBSPILOT) }
                    let row = rows[0]
                    let dbPwd = row.getString(this.colUserPwd)
                    let perm = row.getInt(this.colUserPerm)
                    if (let Some(stored) <- dbPwd && let Some(p) <- perm) {
                        if (bcryptVerify(pwd, stored)) {
                            try { db.update("UPDATE ${this.tableUsers} SET last_login_time=NOW() WHERE ${this.colUserCallsign}=?", cid) } catch (e: Exception) {}
                            return (true, Int32(p))
                        }
                    }
                    return (false, LEV_OBSPILOT)
                } catch (e: Exception) { return (false, LEV_OBSPILOT) }
            case None => return (false, LEV_OBSPILOT)
        }
    }

    public func saveFlightPlan(callsign: String, cid: String, fpData: String): Bool {
        match (this.conn) {
            case Some(db) =>
                try { db.update("INSERT INTO ${this.tableFps} (${this.colFpCallsign}, ${this.colFpCid}, ${this.colFpData}) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE ${this.colFpData}=VALUES(${this.colFpData}), updated_at=NOW()", callsign, cid, fpData); return true }
                catch (e: Exception) { return false }
            case None => return true
        }
    }

    public func getFlightPlan(callsign: String): ?String {
        match (this.conn) {
            case Some(db) =>
                try {
                    let sql = "SELECT ${this.colFpData} FROM ${this.tableFps} WHERE ${this.colFpCallsign}=? LIMIT 1"
                    let rows = db.query(sql, callsign)
                    if (rows.size == 0) { return None }; return rows[0].getString(this.colFpData)
                } catch (e: Exception) { return None }
            case None => return None
        }
    }

    public func deleteFlightPlan(callsign: String): Bool {
        match (this.conn) {
            case Some(db) =>
                try { db.update("DELETE FROM ${this.tableFps} WHERE ${this.colFpCallsign}=?", callsign); return true }
                catch (e: Exception) { return false }
            case None => return true
        }
    }

    // 保存连线时长到数据库（区分飞行员/管制员）
    public func saveOnlineTime(cid: String, ctype: String, durationMin: Int64): Bool {
        if (!this.ensureConnected()) { dolog(L_WARNING, "saveOnlineTime: cannot connect for ${cid}"); return false }
        match (this.conn) {
            case Some(db) =>
                try {
                    let hours = Float64(durationMin) / 60.0
                    if (hours < 0.0167) { return true }
                    dolog(L_DEBUG, "saveOnlineTime: ${cid} ${ctype} +${hours}h (${durationMin}min)")
                    let col = if (ctype == "ATC") { "control_hours" } else { "flight_hours" }
                    let stmt = db.prepareStatement("UPDATE ${this.tableUsers} SET ${col}=${col}+? WHERE ${this.colUserCallsign}=?")
                    try {
                        stmt.set(0, hours.toString())
                        stmt.set(1, cid)
                        let result = stmt.update()
                        if (result.rowCount == 0) {
                            dolog(L_WARNING, "saveOnlineTime: ${cid} affected 0 rows (账号不存在或 user_callsign 不匹配)")
                        } else {
                            dolog(L_DEBUG, "saveOnlineTime: ${cid} done (affected ${result.rowCount} rows)")
                        }
                        return true
                    } catch (e: Exception) {
                        dolog(L_WARNING, "saveOnlineTime failed: ${e}")
                        this.handleDbError(e)
                        return false
                    } finally {
                        try { stmt.close() } catch (_: Exception) {}
                    }
                } catch (e: Exception) {
                    dolog(L_WARNING, "saveOnlineTime prepare failed: ${e}")
                    this.handleDbError(e)
                    return false
                }
            case None => dolog(L_WARNING, "saveOnlineTime: conn is None for ${cid}"); return false
        }
    }

    // 查询用户的飞行时长和管制时长（单位：小时，支持小数）
    public func getUserHours(cid: String): (Float64, Float64) {
        match (this.conn) {
            case Some(db) =>
                try {
                    let rows = db.query("SELECT flight_hours, control_hours FROM ${this.tableUsers} WHERE ${this.colUserCallsign}=?", cid)
                    if (rows.size > 0) {
                        let fhStr = rows[0].getString("flight_hours")
                        let chStr = rows[0].getString("control_hours")
                        if (let Some(fh) <- fhStr && let Some(ch) <- chStr) {
                            return (parseFloat(fh), parseFloat(ch))
                        }
                    }
                } catch (e: Exception) {
                    dolog(L_WARNING, "getUserHours failed: ${e}")
                }
            case None => ()
        }
        return (0.0, 0.0)
    }
}
