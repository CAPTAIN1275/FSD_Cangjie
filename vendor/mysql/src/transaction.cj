package mysql

import std.collection.{ArrayList, HashMap}
import std.database.sql
import mysql.data
import mysql.protocol
import mysql.driver

/**
 * 定义数据库事务的核心行为
*/
public class Transaction <: driver.Transaction {
    public init(pool: data.Pool) {
        super(pool)
    }

    public func prepareStatement(sql: String): driver.Statement {
        match (this.client) {
            case Some(conn)=> driver.Statement(conn, sql)
            case _=> throw Exception("无事务，不能执行预编译")
        }
    }

    /**
     * 扩展任务查询条件
    */
    public func query(sql: String, params: Array<Any>): Array<SqlRowData> {
        let stmt: driver.Statement = this.prepareStatement(sql)

        for (i in 0..params.size) {
            let v = params[i]
            match (v) {
                case v: protocol.SqlData => stmt.set(i, v)
                case v: ?Any => stmt.set(i, protocol.SqlNull())
                case _ => throw Exception("参数类型错误")
            }
        }

        let result: driver.QueryResult = stmt.query()

        let columns = result.columnInfos
        let list = ArrayList<SqlRowData>()

        var (rowBytes, next) = result.readRow()
        while (next) {
            var rowHash = HashMap<String, Array<UInt8>>()
            for (i in 0..rowBytes.size) {
                let column = columns[i]
                rowHash[column.name] = rowBytes[i]
            }

            list.add(RowData(rowHash))
            (rowBytes, next) = result.readRow()
        }
        stmt.close()

        return list.toArray()
    }

    /**
     * 扩展任意更新参数
    */
    public func update(sql: String, params: Array<Any>) {
        let stmt = this.prepareStatement(sql)

        for (i in 0..params.size) {
            let v = params[i]
            match (v) {
                case v: protocol.SqlData => stmt.set(i, v)
                case v: ?Any => stmt.set(i, protocol.SqlNull())
                case _ => throw Exception("参数类型错误")
            }
        }

        
        let result = stmt.update()
        stmt.close()
        return result
    }
}