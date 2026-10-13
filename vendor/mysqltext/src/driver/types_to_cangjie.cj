package mysql.driver

import std.convert.*
import std.binary.*
import std.io.InputStream
import std.io.ByteBuffer
import std.time.*
import std.database.sql
import std.collection.ArrayList
import stdx.crypto.digest.*

public func fromBinary<T>(b: Array<Byte>): T {
    let t: ?T = None
    match (t) {
        case _: ?String => return (String.fromUtf8(b) as T).getOrThrow()
        case _: ?Array<Byte> => return (b as T).getOrThrow()
        case _: ?Int8 => return (Int8.readLittleEndian(b) as T).getOrThrow()
        case _: ?UInt8 => return (UInt8.readLittleEndian(b) as T).getOrThrow()
        case _: ?Int16 => return (Int16.readLittleEndian(b) as T).getOrThrow()
        case _: ?UInt16 => return (UInt16.readLittleEndian(b) as T).getOrThrow()
        case _: ?Int32 => return (Int32.readLittleEndian(b) as T).getOrThrow()
        case _: ?UInt32 => return (UInt32.readLittleEndian(b) as T).getOrThrow()
        case _: ?Int64 => return (Int64.readLittleEndian(b) as T).getOrThrow()
        case _: ?UInt64 => return (UInt64.readLittleEndian(b) as T).getOrThrow()
        case _: ?Float32 => return (Float32.readLittleEndian(b) as T).getOrThrow()
        case _: ?Float64 => return (Float64.readLittleEndian(b) as T).getOrThrow()
        case _: ?DateTime => return (binaryDateTimeToDateTime(b).getOrThrow() as T).getOrThrow()

        case _=> throw Exception("fromBinary TODO sql 接口约束的，需要做转换到支持的类型上")
    }
}

/*
 * MySql二进制转DateTime
 */
protected func binaryDateTimeToDateTime(data: Array<Byte>): ?DateTime {
    if(data.size == 0) {
        return None
    }
    match (data[0]) {
        case 0 => return DateTime.of(year: 0, month: 1, dayOfMonth: 1, second: 0, timeZone: TimeZone.UTC)
        case 4 =>
            var year = UInt16.readLittleEndian(data[1..3])
            var month = data[3]
            var day = data[4]
            return DateTime.of(year: Int64(year), month: Int64(month), dayOfMonth: Int64(day), timeZone: TimeZone.UTC)
        case 7 =>
            var year = UInt16.readLittleEndian(data[1..3])
            var month = data[3]
            var day = data[4]
            var hour = data[5]
            var minute = data[6]
            var second = data[7]
            return DateTime.of(year: Int64(year), month: Int64(month), dayOfMonth: Int64(day), hour: Int64(hour),
                minute: Int64(minute), second: Int64(second), timeZone: TimeZone.Local)
        case 8 =>
            var hour = data[6]
            var minute = data[7]
            var second = data[8]
            return DateTime.of(year: 0, month: 1, dayOfMonth: 1, hour: Int64(hour), minute: Int64(minute), second: Int64(second), timeZone: TimeZone.Local)
        case 11 =>
            var year = UInt16.readLittleEndian(data[1..3])
            var month = data[3]
            var day = data[4]
            var hour = data[5]
            var minute = data[6]
            var second = data[7]
            var micorSecond = UInt16.readLittleEndian(data[8..12])
            return DateTime.of(
                year: Int64(year),
                month: Int64(month),
                dayOfMonth: Int64(day),
                hour: Int64(hour),
                minute: Int64(minute),
                second: Int64(second),
                nanosecond: Int64(micorSecond),
                timeZone: TimeZone.Local
            )
        case _ => throw Exception("to time error")
    }
}

/*
 * MySql二进制转DateTime
 */
protected func binaryTimeToDateTime(data: Array<Byte>): ?DateTime {
    if(data.size == 0) {
        return None
    }
    match (data[0]) {
        case 0 => return DateTime.of(year: 0, month: 1, dayOfMonth: 1, second: 0, timeZone: TimeZone.UTC)
        case 8 =>
            return DateTime.of(
                year: 1970,
                month: 1,
                dayOfMonth: 1,
                hour: Int64(data[7]),
                minute: Int64(data[8]),
                second: Int64(data[9]),
                timeZone: TimeZone.UTC
            )
        case 12 =>
            return DateTime.of(
                year: 1970,
                month: 1,
                dayOfMonth: 1,
                hour: Int64(data[7]),
                minute: Int64(data[8]),
                second: Int64(data[9]),
                nanosecond: Int64(UInt16.readLittleEndian(data[9..13])),
                timeZone: TimeZone.Local
            )
        case _ => throw Exception("to time error")
    }
}