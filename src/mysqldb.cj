package FSD_Cangjie

import mysql
import std.collection.*
import std.net.*
import std.process.*

var gMysql: ?MysqlDB = None

func bcryptVerify(pwd: String, hash: String): Bool {
    if (!hash.startsWith("\$2")) { return pwd == hash }
    // 直接调 PHP 验证 bcrypt
    try {
        let phpCode = "echo password_verify('${pwd}', '${hash}') ? '1' : '0';"
        let (code, stdoutBytes, _) = executeWithOutput("php", ["-r", phpCode])
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

    public func connect(): Bool {
        dolog(L_INFO, "MySQL: Connecting to ${this.database}@${this.host}:${this.port}")
        try {
            let dsn = "${this.user}:${this.password}@tcp(${this.host}:${this.port})/${this.database}"
            let ds = mysql.Driver().open(dsn)
            this.conn = ds.connect()
            this.useMysql = true
            dolog(L_INFO, "MySQL: Connected successfully")
            this.initTables()
            return true
        } catch (e: Exception) {
            dolog(L_WARNING, "MySQL: Connection failed, fallback to cert.txt — ${e}")
            this.conn = None; this.useMysql = false
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
                    this.conn = None; this.useMysql = false
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

    public func disconnect(): Unit { this.conn = None; this.useMysql = false }

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
                        if (cs != None && pw != None && lv != None) {
                            let c = cs.getOrThrow()
                            let p = pw.getOrThrow()
                            let l = Int32(lv.getOrThrow())
                            match (getCert(c)) {
                                case Some(existing) => existing.configure(p, l, mgmtime(), "mysql")
                                case None =>
                                    let cert2 = Certificate(c, p, l, mgmtime(), "mysql")
                                    addCert(cert2)
                            }
                        }
                    }
                    removeInactiveCerts()
                    dolog(L_INFO, "MySQL: Certificates loaded from ${this.tableUsers}")
                    return true
                } catch (e: Exception) {
                    dolog(L_WARNING, "MySQL: loadCertificates failed — ${e}"); return false
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
                    if (dbPwd != None && perm != None) {
                        let stored = dbPwd.getOrThrow()
                        if (bcryptVerify(pwd, stored)) {
                            try { db.update("UPDATE ${this.tableUsers} SET last_login_time=NOW() WHERE ${this.colUserCallsign}=?", cid) } catch (e: Exception) {}
                            return (true, Int32(perm.getOrThrow()))
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
}
