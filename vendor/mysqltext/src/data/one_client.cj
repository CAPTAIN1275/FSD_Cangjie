package mysql.data

import std.collection.concurrent.BlockingQueue
import std.net.TcpSocket
import std.database.sql.SqlException
import std.sync.{AtomicInt64, ReentrantMutex}
import mysql.net.Socket

/**
 * 这里是模拟单个链接方式使用驱动, 100% 官方 database.sql 的实现
 */
public class OneClient <: Pool {
    public var conn: ?Client = None

    public var config: Config

    public init(config: Config) {
        this.config = config
    }

    public func get(): Client {
        return match (conn) {
            case Some(conn) =>
                return this.conn.getOrThrow()
            case None => 
                this.conn = this.newClient()
                return this.conn.getOrThrow()
        }
    }

    public func put(_: Client): Unit {
        // do nothing
    }

    public func del(_: Client):Unit {
        this.conn = newClient()
    }

    public func close(): Unit {
        match (this.conn) {
            case Some(c) =>
                try { c.close() } catch (_: Exception) {}
                this.conn = None
            case None => ()
        }
    }

    protected func newClient(): Client {
        let connect = Socket(this.config.address, this.config.port)

        connect
            .auth()
            .setAddress(this.config.address)
            .setDatabase(this.config.database)
            .setUser(this.config.user)
            .setPassword(this.config.password)
            .connect()

        return Client(connect, this)
    }

    public func size(): Int64 {
        return 1
    }
}
