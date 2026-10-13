package mysql

import std.collection.HashMap
import std.convert.*
import std.time.*

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

// 行数据（文本协议：字段是 UTF-8 文本，按目标类型解析）
public class RowData <: SqlRowData {
    let row: HashMap<String, Array<UInt8>>

    public init(row: HashMap<String, Array<UInt8>>) {
        this.row = row
    }

    // 取原始文本；NULL/空返回 None
    private func text(name: String): ?String {
        if (!this.row.contains(name)) {
            return None
        }
        let arr = this.row[name]
        if (arr.size == 0) {
            return None
        }
        return String.fromUtf8(arr)
    }

    public func getInt(name: String): ?Int64 {
        match (this.text(name)) {
            case Some(s) => try { Int64.parse(s) } catch (_: Exception) { None }
            case None => None
        }
    }

    public func getInt16(name: String): ?Int16 {
        match (this.getInt(name)) {
            case Some(v) => Int16(v)
            case None => None
        }
    }

    public func getInt32(name: String): ?Int32 {
        match (this.getInt(name)) {
            case Some(v) => Int32(v)
            case None => None
        }
    }

    public func getInt64(name: String): ?Int64 {
        return this.getInt(name)
    }

    public func getUInt16(name: String): ?UInt16 {
        match (this.getInt(name)) {
            case Some(v) => UInt16(v)
            case None => None
        }
    }

    public func getUInt32(name: String): ?UInt32 {
        match (this.getInt(name)) {
            case Some(v) => UInt32(v)
            case None => None
        }
    }

    public func getUInt64(name: String): ?UInt64 {
        match (this.getInt(name)) {
            case Some(v) => UInt64(v)
            case None => None
        }
    }

    public func getFloat32(name: String): ?Float32 {
        match (this.text(name)) {
            case Some(s) => try { Float32.parse(s) } catch (_: Exception) { None }
            case None => None
        }
    }

    public func getFloat64(name: String): ?Float64 {
        match (this.text(name)) {
            case Some(s) => try { Float64.parse(s) } catch (_: Exception) { None }
            case None => None
        }
    }

    public func getBool(name: String): ?Bool {
        match (this.getInt(name)) {
            case Some(v) => (v != 0)
            case None => None
        }
    }

    public func getString(name: String): ?String {
        return this.text(name)
    }

    public func getBinary(name: String): ?Array<Byte> {
        if (!this.row.contains(name)) {
            return None
        }
        let arr = this.row[name]
        if (arr.size == 0) {
            return None
        }
        return arr
    }

    public func getTime(name: String): ?DateTime {
        match (this.text(name)) {
            case Some(s) => try { DateTime.parse(s) } catch (_: Exception) { None }
            case None => None
        }
    }
}
