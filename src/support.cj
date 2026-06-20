package FSD_Cangjie

import std.time.*
import std.collection.*

var currentLogLevel: Int32 = L_INFO

func joinStr(fields: ArrayList<String>, sep: String): String {
    var sb = StringBuilder()
    var first = true
    for (f in fields) {
        if (first) { first = false } else { sb.append(sep) }
        sb.append(f)
    }
    return sb.toString()
}

func initLog(_path: String): Unit {}

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

func sprintGmt(_t: Int64): String { return DateTime.now().format("yyyyMMddHHmmss") }
func sprintGmtDate(_t: Int64): String { return DateTime.now().format("yyyyMMdd") }

// ---- 数学辅助（无 std.math）----
func sqrtApprox(x: Float64): Float64 {
    if (x <= 0.0) { return 0.0 }
    var guess = x / 2.0
    for (_i in 0..20) {
        guess = (guess + x / guess) / 2.0
    }
    return guess
}

func cosApprox(deg: Float64): Float64 {
    // 泰勒近似 cos(x) ≈ 1 - x²/2 + x⁴/24 (x 为弧度)
    let rad = deg * 3.1415926535 / 180.0
    let r2 = rad * rad
    let r4 = r2 * r2
    return 1.0 - r2 / 2.0 + r4 / 24.0
}

func calcNMDistance(lat1: Float64, lon1: Float64, lat2: Float64, lon2: Float64): Float64 {
    if (lat1 == 0.0 && lon1 == 0.0) { return -1.0 }
    if (lat2 == 0.0 && lon2 == 0.0) { return -2.0 }
    // 平面近似: 1°纬度=60NM, 1°经度=60*cos(平均纬度)NM
    let meanLat = (lat1 + lat2) / 2.0
    let dlat = (lat2 - lat1) * 60.0
    let dlon = (lon2 - lon1) * 60.0 * cosApprox(meanLat)
    return sqrtApprox(dlat * dlat + dlon * dlon)
}

