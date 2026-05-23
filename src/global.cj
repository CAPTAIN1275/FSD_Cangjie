package FSD_Cangjie

// ============================================================
// 全局常量定义
// ============================================================

let USERTIMEOUT: Int64 = 500
let SERVERTIMEOUT: Int64 = 800
let CLIENTTIMEOUT: Int64 = 800
let SILENTCLIENTTIMEOUT: Int64 = 36000
let WINDDELTATIMEOUT: Int64 = 70
let USERPINGTIMEOUT: Int64 = 200
let USERFEEDCHECK: Int64 = 3
let LAGCHECK: Int64 = 60
let NOTIFYCHECK: Int64 = 10
let SYNCTIMEOUT: Int64 = 120
let SERVERMAXTOOK: Int64 = 240
let MAXHOPS: Int32 = 10
let GUARDRETRY: Int64 = 120
let CALLSIGNBYTES: Int32 = 12
let MAXLINELENGTH: Int32 = 512
let MAXMETARDOWNLOADTIME: Int64 = 900
let CERTFILECHECK: Int64 = 10
let WHAZZUPCHECK: Int64 = 5
let CONNECTDELAY: Int64 = 20
let CONFIGINTERVAL: Int64 = 10
let DEFAULT_CLIENT_PORT: Int32 = 6809
let DEFAULT_SERVER_PORT: Int32 = 3011
let DEFAULT_SYSTEM_PORT: Int32 = 3010
let DEFAULT_HTTP_API_PORT: Int32 = 8080
let NET_BUFFER_SIZE: Int32 = 4096
let HTTP_BUFFER_SIZE: Int32 = 8192

let LEV_SUSPENDED: Int32 = 0
let LEV_OBSPILOT: Int32 = 1
let LEV_REGPILOT: Int32 = 2
let LEV_CERTPILOT: Int32 = 3
let LEV_APPTRAIN: Int32 = 4
let LEV_CTLSTF: Int32 = 5
let LEV_CTLOPS: Int32 = 6
let LEV_CTLSPC: Int32 = 7
let LEV_CTLFLN: Int32 = 8
let LEV_ATMGR: Int32 = 9
let LEV_PICOT: Int32 = 10
let LEV_SUP_ADMIN: Int32 = 11
let LEV_ADMIN: Int32 = 12
let LEV_MAX: Int32 = 12

let CLIENT_ATC: Int32 = 0
let CLIENT_PILOT: Int32 = 1
let SERVER_SILENT: Int32 = 1
let SERVER_METAR: Int32 = 2
let SOURCE_NETWORK: Int32 = 0
let SOURCE_FILE: Int32 = 1
let SOURCE_DOWNLOAD: Int32 = 2
let FEED_IN: Int32 = 0
let FEED_OUT: Int32 = 1
let FEED_BOTH: Int32 = 2
let L_DEBUG: Int32 = 0
let L_INFO: Int32 = 1
let L_WARNING: Int32 = 2
let L_ALERT: Int32 = 3
let L_ERR: Int32 = 4
let PRODUCT: String = "LDP FLY ADS BETA"
let VERSION: String = "FSD 4.0 Cangjie"
let NEEDREVISION: Int32 = 9
let MAX_CLIENTS: Int32 = 500
let MAX_SERVERS: Int32 = 50
let MAX_HTTP_CONNECTIONS: Int32 = 100

func levelName(level: Int32): String {
    if (level == LEV_SUSPENDED) { return "SUSPENDED" }
    if (level == LEV_OBSPILOT) { return "OBSERVER" }
    if (level == LEV_REGPILOT) { return "REGISTERED PILOT" }
    if (level == LEV_CERTPILOT) { return "CERTIFIED PILOT" }
    if (level == LEV_APPTRAIN) { return "APP TRAINEE" }
    if (level == LEV_CTLSTF) { return "CONTROLLER STAFF" }
    if (level == LEV_CTLOPS) { return "CONTROLLER OPS" }
    if (level == LEV_CTLSPC) { return "CONTROLLER SPECIALIST" }
    if (level == LEV_CTLFLN) { return "CONTROLLER INSTRUCTOR" }
    if (level == LEV_ATMGR) { return "AIR TRAFFIC MANAGER" }
    if (level == LEV_PICOT) { return "PILOT COORDINATOR" }
    if (level == LEV_SUP_ADMIN) { return "SUPER ADMIN" }
    if (level == LEV_ADMIN) { return "ADMINISTRATOR" }
    return "UNKNOWN(${level})"
}
