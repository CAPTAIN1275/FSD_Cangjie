package FSD_Cangjie

import std.time.*

var currentLogLevel: Int32 = L_INFO

func initLog(path: String): Unit {}

func dolog(level: Int32, msg: String): Unit {
    if (level < currentLogLevel) { return }
    let levelStr = if (level == L_DEBUG) { "DEBUG" }
        else if (level == L_INFO) { "INFO" }
        else if (level == L_WARNING) { "WARN" }
        else if (level == L_ERR) { "ERROR" }
        else { "UNKN" }
    let now = DateTime.now()
    println("${now.format("yyyy-MM-dd HH:mm:ss")} [${levelStr}] ${msg}")
}

func mgmtime(): Int64 {
    let now = DateTime.now()
    return (now.year - 1970) * 31536000 + now.dayOfYear * 86400 + now.hour * 3600 + now.minute * 60 + now.second
}

func mtime(): Int64 { return mgmtime() }

func sprintGmt(t: Int64): String { return DateTime.now().format("yyyyMMddHHmmss") }
func sprintGmtDate(t: Int64): String { return DateTime.now().format("yyyyMMdd") }
