package mysql.driver

import std.database.sql
import mysql.data
/**
 * 执行 Insert、Update、Delete 语句产生的结果接口
*/
public class UpdateResult <: sql.UpdateResult {
    public var _lastInsertId = 0
    public var _rowCount = 0
    
    public init(count: UInt64, lastID: UInt64){
        this._lastInsertId = Int64(lastID)
        this._rowCount = Int64(count)
    }

    public prop lastInsertId: Int64 {
        get() {
            return this._lastInsertId
        }
    }
    public prop rowCount: Int64 {
        get() {
            return this._rowCount
        }
    }
}