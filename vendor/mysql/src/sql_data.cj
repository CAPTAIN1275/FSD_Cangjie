package mysql

import std.collection.HashMap
import std.convert.*
import std.binary.*
import std.io.InputStream
import std.io.ByteBuffer
import std.time.*
import std.convert.*
internal import mysql.driver.binaryDateTimeToDateTime

// 用户侧数据接口
public interface SqlData {
    func fromSqlData(row: SqlRowData): Unit
    func toSqlData(): HashMap<String, ?Any>
}
// 各种数据库驱动需要实现的数据接口
// 根据反射或生成 class、struct 填充数据
public interface SqlRowData {
    func getInt(name: String): ?Int64
    func getInt16(name: String): ?Int16
    func getInt32(name: String): ?Int32
    func getInt64(name: String): ?Int64
    func getUInt16(name: String): ?UInt16
    func getUInt32(name: String): ?UInt32
    func getUInt64(name: String): ?UInt64
    func getFloat32(name: String): ?Float32
    func getFloat64(name: String): ?Float64
    func getBool(name: String): ?Bool
    func getString(name: String): ?String
    func getBinary(name: String): ?Array<Byte>
    func getTime(name: String): ?DateTime
}

// 行数据
public class RowData <: SqlRowData {
    let row: HashMap<String, Array<UInt8>>

    public init(row: HashMap<String, Array<UInt8>>) {
        this.row = row
    }

    public func getInt(name: String): ?Int64 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        let arr = this.row[name]
        match (arr.size) {
            case 1=> Int64(Int8.readLittleEndian(arr))
            case 2=> Int64(Int16.readLittleEndian(arr))
            case 4=> Int64(Int32.readLittleEndian(arr))
            case 8=> Int64.readLittleEndian(arr)
            case _=> throw Exception("invalid int size")
        }
    }

    public func getInt16(name: String): ?Int16 {
        return match (this.getInt(name)) {
            case Some(v)=> Int16(v)
            case _=> None
        }
    }

    public func getInt32(name: String): ?Int32 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        let arr = this.row[name]
        match (arr.size) {
            case 2=> Int32(Int16.readLittleEndian(arr))
            case 4=> Int32.readLittleEndian(arr)
            case 8=> Int32(Int64.readLittleEndian(arr))
            case _=> throw Exception("invalid int size")
        }
    }

    public func getInt64(name: String): ?Int64 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        let arr = this.row[name]
        match (arr.size) {
            case 4=> Int64(Int32.readLittleEndian(arr))
            case 8=> Int64.readLittleEndian(arr)
            case _=> throw Exception("invalid int size")
        }
    }
    public func getUInt16(name: String): ?UInt16 {
        return match (this.getUInt64(name)) {
            case Some(v)=> UInt16(v)
            case _=> None
        }
    }

    public func getUInt32(name: String): ?UInt32 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        let arr = this.row[name]
        match (arr.size) {
            case 2=> UInt32(UInt16.readLittleEndian(arr))
            case 4=> UInt32.readLittleEndian(arr)
            case 8=> UInt32(Int64.readLittleEndian(arr))
            case _=> throw Exception("invalid int size")
        }
    }

    public func getUInt64(name: String): ?UInt64 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        let arr = this.row[name]
        match (arr.size) {
            case 4=> UInt64(Int32.readLittleEndian(arr))
            case 8=> UInt64.readLittleEndian(arr)
            case _=> throw Exception("invalid int size")
        }
    }

    public func getFloat32(name: String): ?Float32 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        return Float32.readLittleEndian(this.row[name])
    }

    public func getFloat64(name: String): ?Float64 {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        return Float64.readLittleEndian(this.row[name])
    }

    public func getBool(name: String): ?Bool {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        return Bool.readLittleEndian(this.row[name])
    }

    public func getString(name: String): ?String {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        return String.fromUtf8(this.row[name])
    }

    public func getBinary(name: String): ?Array<Byte> {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        return this.row[name]
    }

    public func getTime(name: String): ?DateTime {
        if (!this.row.contains(name)) {
            return None
        }
        if (this.row[name].size == 0) {
            return None
        }
        var date = binaryDateTimeToDateTime(this.row[name])
        return date
    }
}