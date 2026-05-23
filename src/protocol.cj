package FSD_Cangjie

let ERR_OK: Int32 = 0
let ERR_CSINUSE: Int32 = 1
let ERR_CSINVALID: Int32 = 2
let ERR_REGISTERED: Int32 = 3
let ERR_SYNTAX: Int32 = 4
let ERR_SRCINVALID: Int32 = 5
let ERR_CIDINVALID: Int32 = 6
let ERR_NOSUCHCS: Int32 = 7
let ERR_NOFP: Int32 = 8
let ERR_NOWEATHER: Int32 = 9
let ERR_REVISION: Int32 = 10
let ERR_LEVEL: Int32 = 11
let ERR_SERVFULL: Int32 = 12
let ERR_CSSUSPEND: Int32 = 13

let CMD_NOTIFY: Int32 = 0; let CMD_REQMETAR: Int32 = 1; let CMD_PING: Int32 = 2
let CMD_PONG: Int32 = 3; let CMD_SYNC: Int32 = 4; let CMD_LINKDOWN: Int32 = 5
let CMD_NOWX: Int32 = 6; let CMD_ADDCLIENT: Int32 = 7; let CMD_RMCLIENT: Int32 = 8
let CMD_PLAN: Int32 = 9; let CMD_PD: Int32 = 10; let CMD_AD: Int32 = 11
let CMD_CERT: Int32 = 12; let CMD_MULTIC: Int32 = 13; let CMD_WEATHER: Int32 = 14
let CMD_METAR: Int32 = 15; let CMD_ADDWPROF: Int32 = 16; let CMD_DELWPROF: Int32 = 17
let CMD_KILL: Int32 = 18; let CMD_RESET: Int32 = 19
let CL_MESSAGE: Int32 = 20  // 客户端消息（用于 sendMulticast）

let CERT_ADD: Int32 = 0; let CERT_DELETE: Int32 = 1; let CERT_MODIFY: Int32 = 2

func errStr(code: Int32): String {
    if (code == ERR_OK) { return "OK" }
    if (code == ERR_CSINUSE) { return "Callsign in use" }
    if (code == ERR_CSINVALID) { return "Callsign invalid" }
    if (code == ERR_REGISTERED) { return "Already registered" }
    if (code == ERR_SYNTAX) { return "Syntax error" }
    if (code == ERR_SRCINVALID) { return "Invalid source" }
    if (code == ERR_CIDINVALID) { return "Invalid CID/password" }
    if (code == ERR_NOSUCHCS) { return "No such callsign" }
    if (code == ERR_NOFP) { return "No flightplan" }
    if (code == ERR_NOWEATHER) { return "No such weather profile" }
    if (code == ERR_REVISION) { return "Invalid protocol revision" }
    if (code == ERR_LEVEL) { return "Requested level too high" }
    if (code == ERR_SERVFULL) { return "No more clients" }
    if (code == ERR_CSSUSPEND) { return "CID suspended" }
    return "Unknown error"
}
