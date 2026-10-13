package mysql.driver

import std.collection.{Map,HashMap}
import std.database.sql
import mysql.data.Pool

/**
 * 数据库连接接口
*/
public open class Connection <: sql.Connection {
    protected let pool: Pool
    public init(pool: Pool){
        this.pool = pool
    }

    protected var _state = sql.ConnectionState.Closed
    /**
     * 描述与数据源连接的当前状态
     */
    public override prop state: sql.ConnectionState {
        get() {
            return this._state
        }
    }
    /**
     * 创建事务
     */
    public open func createTransaction(): Transaction {
        // 这个对象不分配链接, 需要再 begin 后再分配链接
        Transaction(this.pool)
    }
    /**
     * 获取数据库元数据
     */
    public func getMetaData(): Map<String, String> {
        HashMap([])
    }
    
    /**
     * 创建预处理语句
     */
    public open func prepareStatement(sql: String): Statement {
        let client = this.pool.get()
        try {
            return Statement(client, sql)
        } catch (e: Exception) {
            // 构造失败（如服务端返回错误）也必须归还/丢弃连接，否则连接池会被逐渐耗尽
            try { client.release() } catch (_: Exception) {}
            throw e
        }
    }

    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {}
}