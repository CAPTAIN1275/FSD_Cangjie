package FSD_Cangjie

import std.collection.*

// ============================================================
// String 扩展和工具函数
// ============================================================

extend String {
    func indexOf(ch: Rune): ?Int64 {
        let chars = this.toRuneArray()
        for (i in 0..chars.size) { if (chars[i] == ch) { return i } }
        return None
    }

    func toUpper(): String {
        let chars = this.toRuneArray()
        var sb = StringBuilder()
        for (ch in chars) {
            if (ch >= r'a' && ch <= r'z') {
                // 小写转大写：'a' - 'A' = 32
                if (ch == r'a') { sb.append(r'A') } else if (ch == r'b') { sb.append(r'B') }
                else if (ch == r'c') { sb.append(r'C') } else if (ch == r'd') { sb.append(r'D') }
                else if (ch == r'e') { sb.append(r'E') } else if (ch == r'f') { sb.append(r'F') }
                else if (ch == r'g') { sb.append(r'G') } else if (ch == r'h') { sb.append(r'H') }
                else if (ch == r'i') { sb.append(r'I') } else if (ch == r'j') { sb.append(r'J') }
                else if (ch == r'k') { sb.append(r'K') } else if (ch == r'l') { sb.append(r'L') }
                else if (ch == r'm') { sb.append(r'M') } else if (ch == r'n') { sb.append(r'N') }
                else if (ch == r'o') { sb.append(r'O') } else if (ch == r'p') { sb.append(r'P') }
                else if (ch == r'q') { sb.append(r'Q') } else if (ch == r'r') { sb.append(r'R') }
                else if (ch == r's') { sb.append(r'S') } else if (ch == r't') { sb.append(r'T') }
                else if (ch == r'u') { sb.append(r'U') } else if (ch == r'v') { sb.append(r'V') }
                else if (ch == r'w') { sb.append(r'W') } else if (ch == r'x') { sb.append(r'X') }
                else if (ch == r'y') { sb.append(r'Y') } else if (ch == r'z') { sb.append(r'Z') }
            } else {
                sb.append(ch)
            }
        }
        return sb.toString()
    }

    func trim(): String {
        let chars = this.toRuneArray()
        var start: Int64 = 0; var end: Int64 = chars.size
        while (start < end && (chars[start] == r' ' || chars[start] == r'\t')) { start += 1 }
        while (end > start && (chars[end-1] == r' ' || chars[end-1] == r'\t' || chars[end-1] == r'\r' || chars[end-1] == r'\n')) { end -= 1 }
        var sb = StringBuilder()
        for (i in start..end) { sb.append(chars[i]) }
        return sb.toString()
    }
}

func substr(s: String, start: Int64, end: Int64): String {
    let chars = s.toRuneArray(); var sb = StringBuilder(); var idx: Int64 = 0
    for (ch in chars) { if (idx >= start && idx < end) { sb.append(ch) }; if (idx >= end) { break }; idx += 1 }
    return sb.toString()
}

func substrFrom(s: String, start: Int64): String { return substr(s, start, s.toRuneArray().size) }
func substrTo(s: String, end: Int64): String { return substr(s, 0, end) }

func splitStr(s: String, sep: String): Array<String> {
    var result = ArrayList<String>()
    var current = StringBuilder()
    let sepRunes = sep.toRuneArray()
    let chars = s.toRuneArray()
    var i: Int64 = 0
    while (i < chars.size) {
        var matched = true
        for (j in 0..sepRunes.size) {
            if (i + j >= chars.size || chars[i + j] != sepRunes[j]) { matched = false; break }
        }
        if (matched) {
            result.add(current.toString())
            current = StringBuilder()
            i += sepRunes.size
        } else {
            current.append(chars[i])
            i += 1
        }
    }
    result.add(current.toString())
    return result.toArray()
}

func parseInt32(s: String): Int32 {
    let MAX_DIV10: Int32 = 214748364  // Int32.MAX / 10
    var result: Int32 = 0
    for (ch in s.toRuneArray()) {
        if (ch >= r'0' && ch <= r'9') {
            let d = runeToDigit(ch)
            if (result > MAX_DIV10) { return 2147483647 }  // 溢出时返回 MAX
            result = result * 10 + d
        }
    }
    return result
}

func parseInt64(s: String): Int64 {
    let MAX_DIV10: Int64 = 922337203685477580  // Int64.MAX / 10
    var result: Int64 = 0
    for (ch in s.toRuneArray()) {
        if (ch >= r'0' && ch <= r'9') {
            let d = Int64(runeToDigit(ch))
            if (result > MAX_DIV10) { return 9223372036854775807 }  // 溢出时返回 MAX
            result = result * 10 + d
        }
    }
    return result
}

func parseFloat(s: String): Float64 {
    var result: Float64 = 0.0; var decimal: Float64 = 0.0
    var divisor: Float64 = 1.0; var inDecimal: Bool = false
    for (ch in s.toRuneArray()) {
        if (ch == r'.') { inDecimal = true }
        else if (ch >= r'0' && ch <= r'9') {
            if (inDecimal) { decimal = decimal * 10.0 + Float64(runeToDigit(ch)); divisor *= 10.0 }
            else { result = result * 10.0 + Float64(runeToDigit(ch)) }
        }
    }
    return result + decimal / divisor
}

func runeToDigit(ch: Rune): Int32 {
    if (ch == r'0') { return 0 } else if (ch == r'1') { return 1 }
    else if (ch == r'2') { return 2 } else if (ch == r'3') { return 3 }
    else if (ch == r'4') { return 4 } else if (ch == r'5') { return 5 }
    else if (ch == r'6') { return 6 } else if (ch == r'7') { return 7 }
    else if (ch == r'8') { return 8 } else if (ch == r'9') { return 9 }
    return 0
}
