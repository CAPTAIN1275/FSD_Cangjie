package mysql.protocol

import std.database.sql
import std.collection.ArrayList
import std.binary.*
import std.time.DateTime

extend Array<Byte> {
    // 长度编码整数
    func readLengthEncodedInteger(pos: Int64): (Int64, Bool, Int64) {
        if (this.size == 0) {
            return (0, true, 1)
        }

        match (this[pos]) {
            // 251: NULL
            case 0xfb => (pos, true, 1)
            // 252: value of following 2
            case 0xfc => return ((Int64(this[1+pos]) | (Int64(this[2+pos]) << 8)),false, 2)
            // 253: value of following 3
            case 0xfd => return ((Int64(this[1+pos]) | (Int64(this[2+pos]) << 8) | (Int64(this[3+pos]) << 16)), false, 3)
            // 254: value of following 8
            case 0xfe => return (
                (Int64(this[1]) | 
                Int64(this[2+pos]) << 8 | 
                Int64(this[3+pos]) << 16 | 
                Int64(this[4+pos]) << 24 |
                Int64(this[5+pos]) << 32 |
                Int64(this[6+pos]) << 40 |
                Int64(this[7+pos]) << 48 |
                Int64(this[8+pos]) << 56),
                false, 
                8
            )
            // 0-250: value of first byte
            case _ => return (Int64(this[pos]), false, 1)
        }
    }

    func readLengthEncodedString(pos: Int64): (String, Int64) {
        var (len, isNull, size) = this.readLengthEncodedInteger(pos)
        if (isNull) {
            return ("", pos + size + len)
        }
        let start = pos + size
        let stop = start + len
        let bytes = this[start..stop]

        return (String.fromUtf8(bytes), stop)
    }
}
