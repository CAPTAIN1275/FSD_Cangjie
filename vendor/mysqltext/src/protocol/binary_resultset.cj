package mysql.protocol

import std.database.sql.SqlException

/*
 * 二进制协议 Resultset 类似于文本 Resultset。
 * 
 * 它只包含 Binary Protocol Resultset Row 格式的行。
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_binary_resultset.html
 */
public class BinaryResultset {
    public var row: Array<Array<Byte>>

    public init(data: Array<Byte>, columns: Array<ColumnDefinition>) {
        // NULL-bitmap,  [(column-count + 7 + 2) / 8 bytes]
        var pos: Int64 = 1 + ((columns.size + 7 + 2) >> 3)
        let nullMask = data[1..pos]

        row = Array<Array<UInt8>>(columns.size, repeat: Array<UInt8>())
        
        for (i in 0..columns.size) {
            // Field is NULL
            // (byte >> bit-pos) % 2 == 1
            if (((nullMask[(i + 2) >> 3] >> UInt64((i + 2) & 7)) & 1) == 1) {
                row[i] = Array<UInt8>()
                continue
            }

            let column = columns[i]
            // https://dev.mysql.com/doc/dev/mysql-server/latest/field__types_8h.html
            match (column._columnType) {
                // fieldTypeNULL 数据库返回的值是 NULL
                case 6 => row[i] = Array<UInt8>()
                // fieldTypeTiny 数字类型
                case 1 =>
                    row[i] = [data[pos]]
                    pos++
                // fieldTypeShort, fieldTypeYear:
                case 2 | 13 =>
                    row[i] = data[pos..pos + 2]
                    pos += 2
                // fieldTypeInt24, fieldTypeLong, fieldTypeFloat
                case 9 | 3 | 4 =>
                    row[i] = data[pos..pos + 4]
                    pos += 4
                // fieldTypeLongLong, fieldTypeDouble
                case 8 | 5 =>
                    row[i] = data[pos..pos + 8]
                    pos += 8
                // 二进制数据类型 | 字符串
                case 0 | 246 | 15 | 16 | 247 | 248 | 249 | 250 | 251 | 252 | 253 | 254 | 255 | 245 =>
                    var checkData = data[pos..]
                    var (tmp, _, n) = readLengthEncodedString(checkData)
                    pos += n
                    row[i] = tmp
                // 时间格式
                case 7 | 10 | 12 | 11 | 14 =>
                    let length = data[pos]
                    row[i] = data[pos..pos + Int64(length) + 1]
                    pos = pos + 1 + Int64(length)
                case _ => throw SqlException("未定义的数据库类型 column.fieldType = ${column._columnType}")
            }
        }
    }
}