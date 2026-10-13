package mysql

import std.database.sql
import std.collection.{ArrayList, HashMap}
import mysql.data
import mysql.driver
import mysql.protocol

/**
 * 数据库连接接口
 */
public class Connection <: driver.Connection {
    public init(pool: data.Pool) {
        super(pool)
    }
    
    /**
     * 扩展任务查询条件
    */
    public func query(sql: String, params: Array<Any>): Array<SqlRowData> {
        let stmt = this.prepareStatement(sql)

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

    public func createTransaction(): Transaction {
        return Transaction(this.pool)
    }

    public func transaction(exec: (tx: Transaction) -> Bool): Bool {
        let tx: Transaction = this.createTransaction()
        try {
            tx.begin()
            if (exec(tx)) {
                tx.commit()
                return true
            }
            tx.rollback()
        } catch (e: Exception) {
            tx.rollback()
            throw e
        }
        return false
    }
}