// support.cj — 辅助函数
package FSD_Cangjie

import std.time.*
import std.collection.*
import std.sync.*

var currentLogLevel: Int32 = L_INFO
// 日志输出锁：dolog 会被数百个 serve 线程并发调用，println 非线程安全
var logLock = Mutex()

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
    let levelStr = if (level == L_DEBUG) { "DEBUG" } else if (level == L_INFO) { "INFO" } else if (level == L_WARNING) { "WARN" } else if (level == L_ERR) { "ERROR" } else { "UNKN" }
    let now = DateTime.now()
    let line = "${now.format("yyyy-MM-dd HH:mm:ss")} [${levelStr}] ${msg}"
    synchronized(logLock) { print(line + "\n", flush: true) }
}

// 年基偏移缓存：mgmtime 被高频调用，年基(年数+闰年天数)只在跨年时重算一次
var _mtYear: Int64 = -1
var _mtBase: Int64 = 0
func mgmtime(): Int64 {
    let now = DateTime.now()
    let y = Int64(now.year)
    if (y != _mtYear) {
        _mtYear = y
        // 计算从 1970 到 y-1 之间的闰年数量
        let leapYears = ((y - 1) / 4 - (y - 1) / 100 + (y - 1) / 400) - (1969 / 4 - 1969 / 100 + 1969 / 400)
        _mtBase = (y - 1970) * 31536000 + leapYears * 86400
    }
    return _mtBase + Int64(now.dayOfYear - 1) * 86400 + Int64(now.hour) * 3600 + Int64(now.minute) * 60 + Int64(now.second)
}
func mtime(): Int64 { return mgmtime() }

// 呼号合法性：仅允许 A-Z 0-9 _ -，长度 2..CALLSIGNBYTES（防协议/边界注入）
func isValidCallsign(cs: String): Bool {
    let rs = cs.toRuneArray()
    if (rs.size < 2 || rs.size > Int64(CALLSIGNBYTES)) { return false }
    for (r in rs) {
        let ok = (r >= r'A' && r <= r'Z') || (r >= r'0' && r <= r'9') || r == r'_' || r == r'-'
        if (!ok) { return false }
    }
    return true
}

func _isLeapYear(y: Int64): Bool { return (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0) }
func _pad2(n: Int64): String { return if (n < 10) { "0${n}" } else { "${n}" } }

// 由 Unix 秒（本地口径，与 mgmtime 一致）反推 yyyyMMddHHmmss
func sprintGmt(t: Int64): String {
    var days = t / 86400
    var rem = t % 86400
    if (rem < 0) { rem += 86400; days -= 1 }
    let hh = rem / 3600
    let mm = (rem % 3600) / 60
    let ss = rem % 60
    var y = 1970
    while (true) {
        let dy = if (_isLeapYear(y)) { 366 } else { 365 }
        if (days < dy) { break }
        days -= dy; y += 1
    }
    let mdays: Array<Int64> = if (_isLeapYear(y)) { [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] } else { [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] }
    var mo = 0
    while (days >= mdays[mo]) { days -= mdays[mo]; mo += 1 }
    let dd = days + 1
    return "${y}${_pad2(mo + 1)}${_pad2(dd)}${_pad2(hh)}${_pad2(mm)}${_pad2(ss)}"
}
func sprintGmtDate(t: Int64): String { return substr(sprintGmt(t), 0, 8) }

func sqrtApprox(x: Float64): Float64 {
    if (x <= 0.0) { return 0.0 }
    var guess = x / 2.0
    for (_i in 0..20) { guess = (guess + x / guess) / 2.0 }
    return guess
}

let PI: Float64 = 3.141592653589793
func absF(x: Float64): Float64 { return if (x < 0.0) { -x } else { x } }

func cosApprox(deg: Float64): Float64 {
    let rad = deg * PI / 180.0; let r2 = rad * rad; let r4 = r2 * r2; let r6 = r4 * r2
    return 1.0 - r2 / 2.0 + r4 / 24.0 - r6 / 720.0
}

// 弧度版三角函数（5 阶泰勒展开，精度约 0.01°）
func sinRad(x: Float64): Float64 {
    var a = x; while (a > PI) { a -= 2.0 * PI }; while (a < -PI) { a += 2.0 * PI }
    let a2 = a * a; let a3 = a2 * a; let a5 = a3 * a2; let a7 = a5 * a2
    return a - a3 / 6.0 + a5 / 120.0 - a7 / 5040.0
}
func cosRad(x: Float64): Float64 {
    var a = x; while (a > PI) { a -= 2.0 * PI }; while (a < -PI) { a += 2.0 * PI }
    let a2 = a * a; let a4 = a2 * a2; let a6 = a4 * a2
    return 1.0 - a2 / 2.0 + a4 / 24.0 - a6 / 720.0
}
func atan2Rad(y: Float64, x: Float64): Float64 {
    if (x == 0.0) { return if (y > 0.0) { PI / 2.0 } else if (y < 0.0) { -PI / 2.0 } else { 0.0 } }
    let absY = absF(y); let absX = absF(x)
    let r = if (absY <= absX) { absY / absX } else { absX / absY }
    let r2 = r * r; let r3 = r2 * r; let r5 = r3 * r2; let r7 = r5 * r2
    var ang = r - r3 / 3.0 + r5 / 5.0 - r7 / 7.0
    if (absY > absX) { ang = PI / 2.0 - ang }
    if (x < 0.0) { ang = PI - ang }
    return if (y < 0.0) { -ang } else { ang }
}

func calcNMDistance(lat1: Float64, lon1: Float64, lat2: Float64, lon2: Float64): Float64 {
    if (lat1 == 0.0 && lon1 == 0.0) { return -1.0 }
    if (lat2 == 0.0 && lon2 == 0.0) { return -2.0 }
    let meanLat = (lat1 + lat2) / 2.0
    let dlat = (lat2 - lat1) * 60.0
    let dlon = (lon2 - lon1) * 60.0 * cosApprox(meanLat)
    return sqrtApprox(dlat * dlat + dlon * dlon)
}

// 计算两点间方位角（度）
func calcBearing(lat1: Float64, lon1: Float64, lat2: Float64, lon2: Float64): Float64 {
    if (lat1 == lat2 && lon1 == lon2) { return 0.0 }
    let dlon = (lon2 - lon1) * PI / 180.0
    let rlat1 = lat1 * PI / 180.0; let rlat2 = lat2 * PI / 180.0
    let y = sinRad(dlon) * cosRad(rlat2)
    let x = cosRad(rlat1) * sinRad(rlat2) - sinRad(rlat1) * cosRad(rlat2) * cosRad(dlon)
    let bearing = atan2Rad(y, x) * 180.0 / PI
    return if (bearing < 0.0) { bearing + 360.0 } else { bearing }
}

// LCG 随机数
var _randState: Int64 = 0
func randSeed(s: Int64): Unit { _randState = s }
func randInt(max: Int64): Int64 {
    if (_randState == 0) { _randState = mgmtime() }
    _randState = (_randState * 1103515245 + 12345) & 0x7fffffff
    return if (max <= 0) { _randState } else { _randState % max }
}
func randFloat(): Float64 { return Float64(randInt(1000000)) / 1000000.0 }

// 格式化浮点数为 1 位小数（如 505.5）
func formatFloat(v: Float64): String {
    let i = Int64(v * 10.0)
    let whole = i / 10
    let frac = i % 10
    if (frac == 0) { return "${whole}" }
    return "${whole}.${frac}"
}
