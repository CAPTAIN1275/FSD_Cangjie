package mysql.protocol

import std.collection.*
import std.database.sql.SqlException
import std.collection.*
import stdx.crypto.keys.*
import stdx.crypto.digest.*
import std.io.*
import std.binary.*

// 对原始数组进行操作
public func listCopyList(dest: ArrayList<UInt8>, destStart: Int, src: ArrayList<UInt8>, srcStart: Int, srcStop: Int): Int64 {
    var i = 0
    var destStartVal = destStart
    if ((dest.size - destStart) < (srcStop - srcStart)) {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            if (dest.size > destStartVal) {
                dest[destStartVal] = sv
            } else {
                dest.add(sv)
            }
            destStartVal++
            i++
        }
    } else {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            dest[destStartVal] = sv
            destStartVal++
            i++
        }
    }

    return i
}
// 对原始数组进行操作
public func listCopyArray(dest: ArrayList<UInt8>, destStart: Int, src: Array<UInt8>, srcStart: Int, srcStop: Int): Int64 {
    var i = 0
    var destStartVal = destStart
    if ((dest.size - destStart) < (srcStop - srcStart)) {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            if (dest.size > destStartVal) {
                dest[destStartVal] = sv
            } else {
                dest.add(sv)
            }
            destStartVal++
            i++
        }
    } else {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            dest[destStartVal] = sv
            destStartVal++
            i++
        }
    }

    return i
}

public func listCopyString(dest: ArrayList<UInt8>, destStart: Int, src: String): Int64 {
    let srcStart: Int = 0
    let srcStop: Int = src.size

    var i = 0
    var destStartVal = destStart
    if ((dest.size - destStart) < (srcStop - srcStart)) {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            if (dest.size > destStartVal) {
                dest[destStartVal] = sv
            } else {
                dest.add(sv)
            }
            destStartVal++
            i++
        }
    } else {
        for (si in srcStart..srcStop) {
            let sv = src[si]

            dest[destStartVal] = sv
            destStartVal++
            i++
        }
    }

    return i
}

// encodes a uint64 value and appends it to the given bytes slice
func appendLengthEncodedInteger(b: ArrayList<UInt8>, n: Int64): ArrayList<UInt8> {
    if (n <= 250) {
        b.add(UInt8(n))
        return b
    }
    if (n <= 0xffff) {
        b.add(UInt8(0xfc))
        b.add(UInt8(n & 0xFF))
        b.add(UInt8(n >> 8))
        return b
    }
    if (n <= 0xffffff) {
        b.add(UInt8(0xfd))
        b.add(UInt8(n & 0xFF))
        b.add(UInt8(n >> 8))
        b.add(UInt8(n >> 16))
        return b
    }

    b.add(UInt8(0xfd))
    b.add(UInt8(n & 0xFF))
    b.add(UInt8(n >> 8))
    b.add(UInt8(n >> 16))
    b.add(UInt8(n >> 24))
    b.add(UInt8(n >> 32))
    b.add(UInt8(n >> 40))
    b.add(UInt8(n >> 48))
    b.add(UInt8(n >> 56))
    return b
}

// 计算
func appendLengthEncodedInteger(n: Int64): ArrayList<UInt8> {
    var b = ArrayList<UInt8>()
    if (n <= 250) {
        b.add(UInt8(n))
        return b
    }
    if (n <= 0xffff) {
        b.add(UInt8(0xfc))
        b.add(UInt8(n & 0xFF))
        b.add(UInt8(n >> 8))
        return b
    }
    if (n <= 0xffffff) {
        b.add(UInt8(0xfd))
        b.add(UInt8(n & 0xFF))
        b.add(UInt8(n >> 8))
        b.add(UInt8(n >> 16))
        return b
    }

    b.add(UInt8(0xfd))
    b.add(UInt8(n & 0xFF))
    b.add(UInt8(n >> 8))
    b.add(UInt8(n >> 16))
    b.add(UInt8(n >> 24))
    b.add(UInt8(n >> 32))
    b.add(UInt8(n >> 40))
    b.add(UInt8(n >> 48))
    b.add(UInt8(n >> 56))
    return b
}

// 返回读取的个数、值是否为NULL以及读取的字节数
func readLengthEncodedInteger(b: Array<UInt8>): (UInt64, Bool, Int) {
    if (b.size == 0) {
        return (0, true, 1)
    }

    match (b[0]) {
        // 251: NULL
        case 0xfb => return (0, true, 1)
        // 252: value of following 2
        case 0xfc => return (UInt64(b[1]) | UInt64(b[2]) << 8, false, 3)
        // 253: value of following 3
        case 0xfd => return (UInt64(b[1]) | UInt64(b[2]) << 8 | UInt64(b[3]) << 16, false, 4)
        // 254: value of following 8
        case 0xfe => return (UInt64(b[1]) | UInt64(b[2]) << 8 | UInt64(b[3]) << 16 | UInt64(b[4]) << 24 |
                UInt64(b[5]) << 32 | UInt64(b[6]) << 40 | UInt64(b[7]) << 48 | UInt64(b[8]) << 56, false, 9)
        // 0-250: value of first byte
        case _ => return (UInt64(b[0]), false, 1)
    }
}

/*
 * 从字节流读取一个数字
 */
func readLengthEncodedUInt64(b: Array<Byte>): UInt64 {
    if (b.size == 0) {
        return 0
    }
    match (b[0]) {
        case 0xfc =>
            return littleEndianToUInt64(b[1..3])
        case 0xfd =>
            return littleEndianToUInt64(b[1..4])
        case 0xfe =>
            return littleEndianToUInt64(b[1..9])
        case 0xff => throw Exception("无法正常读取信息包, 读取数字时候遇到0xff")
        case _ => UInt64(b[0])
    }
}

//从字节切片b读取长度编码字符串的长度。
//如果值为NULL，则返回原切片中的子切片、true及已读字节数。
//若非NULL，则根据长度返回相应子字符串（作为字节切片）、false及已读字节数。
//若输入切片不足以包含整个字符串，则返回错误EOF。
func readLengthEncodedString(b: Array<UInt8>): (Array<UInt8>, Bool, Int64) {
    // Get length
    var (num, isNull, n) = readLengthEncodedInteger(b)
    if (num < 1) {
        return (b[n..n], isNull, n)
    }

    n += Int64(num)

    // Check data length
    if (b.size >= n) {
        return (b[n - Int64(num)..n], false, n)
    }
    throw SqlException("EOF")
}

func truncateToByte(number: UInt32): UInt8 {
    return UInt8(number & 0xFF);
}

/*
 * 小端序字节数组转UInt32
 */
func littleEndianToUInt32(form: Array<Byte>): UInt32 {
    var result: UInt32 = 0;
    var i = 0;
    for (v in form) {
        result |= UInt32(v) << 8 * i
        i++
    }
    return result
}

/*
 * 小端序字节数组转UInt16
 */
func littleEndianToUInt16(form: Array<Byte>): UInt16 {
    var result: UInt16 = 0;
    var i = 0;
    for (v in form) {
        result |= UInt16(v) << 8 * i
        i++
    }
    return result
}
/*
 * 小端序字节数组转Int64
 */
func littleEndianToInt64(form: Array<Byte>): Int64 {
    var result: Int64 = 0;
    var i = 0;
    for (v in form) {
        result |= Int64(v) << 8 * i
        i++
    }
    return result
}

/*
 * 小端序字节数组转UInt64
 */
func littleEndianToUInt64(form: Array<Byte>): UInt64 {
    var result: UInt64 = 0;
    var i = 0;
    for (v in form) {
        result |= UInt64(v) << 8 * i
        i++
    }
    return result
}