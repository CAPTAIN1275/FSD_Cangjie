package mysql.driver

import std.database.sql
import mysql.data
import mysql.protocol

/**
 * 定义数据库事务的核心行为
*/
public open class Transaction <: sql.Transaction {
    protected let pool: data.Pool
    protected var client: ?data.Client = None
    public init(pool: data.Pool){
        this.pool = pool
    }

    private var _isoLevel = sql.TransactionIsoLevel.Unspecified
    public mut prop isoLevel: sql.TransactionIsoLevel {
        get() {
            this._isoLevel
        }
        set(v) {
            this._isoLevel = v
        }
    }
    var _accessMode = sql.TransactionAccessMode.ReadWrite
    public mut prop accessMode: sql.TransactionAccessMode {
        get() {
            this._accessMode
        }
        set(v) {
            this._accessMode = v
        }
    }
    var _deferrableMode = sql.TransactionDeferrableMode.NotDeferrable
    public mut prop deferrableMode: sql.TransactionDeferrableMode {
        get() {
            this._deferrableMode
        }
        set(v) {
            this._deferrableMode = v
        }
    }

    public func begin(): Unit {
        match (this.client) {
            case None =>
                let conn = pool.get()
                this.client = conn
                conn.beginTransaction()

                // TODO START TRANSACTION READ ONLY
                let sql = "START TRANSACTION"
                conn.command(protocol.CommandType.Query, sql)
                conn.okResponse()
            case _=> throw Exception("有事务未结束，不能开始事务")
        }
    }

    /*
     * 提交数据库事务。
     *
     * 异常 SqlException - 提交数据库事务失败。
     */
    public override func commit(): Unit {
        match (this.client) {
            case Some(conn) =>
                // 发送指令
                conn.command(protocol.CommandType.Query, "COMMIT")
                conn.okResponse()
                conn.closeTransaction()
                conn.release()
            case None => Exception("有事务未结束，不能开始事务")
        }
    }

    public func release(_: String): Unit {}
    /*
     * 从挂起状态回滚事务。
     *
     * 异常 SqlException - 从挂起状态回滚事务失败。
     */
    public override func rollback(): Unit {
        match (this.client) {
            case Some(conn) =>
                // 发送指令
                conn.command(protocol.CommandType.Query, "ROLLBACK")
                conn.okResponse()
                conn.closeTransaction()
                conn.release()
            case None => Exception("有事务未结束，不能开始事务")
        }
    }

    public func rollback(name: String): Unit {
        this.client.getOrThrow().command(protocol.CommandType.Query, "ROLLBACK TO SAVEPOINT ${name}")
        this.client.getOrThrow().okResponse()
    }
    public func save(name: String): Unit {
        this.client.getOrThrow().command(protocol.CommandType.Query, "SAVEPOINT ${name}")
        this.client.getOrThrow().okResponse()
    }
}
