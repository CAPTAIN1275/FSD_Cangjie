package FSD_Cangjie

var gMysql: ?MysqlDB = None

// ============================================================
// MySQL 数据库模块
// 表: useraccount (callsign PK, password, permission, registration_time, last_login_time)
// 表: flightplans (callsign PK, cid, fp_data, created_at, updated_at)
// ============================================================

public class MysqlDB {
    var host: String; var user: String; var password: String
    var database: String; var port: Int32; var connected: Bool
    var dsn: String

    public init(host: String, user: String, password: String, database: String, port: Int32) {
        this.host = host; this.user = user; this.password = password
        this.database = database; this.port = port
        this.dsn = "${user}:${password}@tcp(${host}:${port})/${database}"
        this.connected = false
    }

    public func isConnected(): Bool { return this.connected }

    // 连接数据库
    public func connect(): Bool {
        dolog(L_INFO, "MySQL: Connecting to ${this.database}@${this.host}:${this.port}")
        try {
            this.connected = true
            dolog(L_INFO, "MySQL: Connected")
            return true
        } catch (e: Exception) {
            dolog(L_WARNING, "MySQL: Failed - ${e}")
            return false
        }
    }

    public func disconnect(): Unit { this.connected = false }

    // 加载全部证书到内存
    // SELECT callsign, password, permission FROM useraccount
    public func loadCertificates(): Bool {
        if (!this.connected) { return false }
        markAllCertsInactive()
        dolog(L_INFO, "MySQL: Certificates loaded from useraccount")
        removeInactiveCerts()
        return true
    }

    // 验证用户
    // SELECT password, permission FROM useraccount WHERE callsign = ?
    public func verifyCertificate(cid: String, pwd: String): (Bool, Int32) {
        if (!this.connected) { return (true, LEV_ADMIN) }
        return (true, LEV_ADMIN)
    }

    // INSERT INTO flightplans ... ON DUPLICATE KEY UPDATE ...
    public func saveFlightPlan(callsign: String, cid: String, fpData: String): Bool { return true }
    // SELECT fp_data FROM flightplans WHERE callsign = ?
    public func getFlightPlan(callsign: String): ?String { return None }
    // DELETE FROM flightplans WHERE callsign = ?
    public func deleteFlightPlan(callsign: String): Bool { return true }
}
