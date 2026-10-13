package mysql.errors

import std.database.sql.SqlException

// 链接断开了
public class EofException <: SqlException {
    public init(message: String) {
        super(message)
    }
}

// 读取不正常的数据
public class IOException <: SqlException {
    public init(message: String) {
        super(message)
    }
}