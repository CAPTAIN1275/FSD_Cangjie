package mysql.data

import std.collection.concurrent.LinkedBlockingQueue
import std.collection.ArrayList
import std.net.TcpSocket
import std.database.sql.SqlException
import std.sync.{AtomicInt64, Mutex}
import mysql.net.Socket

/**
 * 这里是模拟单个链接方式使用驱动, 100% 官方 database.sql 的实现
 */
public class MultipleClient <: Pool {
    protected let queue: LinkedBlockingQueue<Client>
    // 忙碌的链接数
    protected var using = AtomicInt64(0)

    protected var mtx: Mutex = Mutex()

    // 追踪所有创建过的连接，便于 close() 时全部关闭（含正在使用/卡住的）
    protected let allClients = ArrayList<Client>()
    protected let allMtx: Mutex = Mutex()

    public var config: Config

    public init(config: Config) {
        this.config = config
        this.queue = LinkedBlockingQueue<Client>(config.poolMaxCount)
        if (config.poolMinSize > 0) {
            for (_ in 0..config.poolMinSize) {
                this.queue.add(this.newClient())
            }
        }
    }

    public func get(): Client {
        // 先非阻塞尝试
        match (this.queue.remove(Duration.microsecond * 0)) {
            case Some(conn) =>
                this.using.fetchAdd(1)
                return conn
            case None => ()
        }
        // 未达上限则扩容
        if ((this.queue.size + this.using.load()) < this.config.poolMaxCount) {
            this.tryConnMore()
        }
        // 最多等待 30 秒，避免旧实现那样无限递归自旋把服务器挂死
        match (this.queue.remove(Duration.second * 30)) {
            case Some(conn) =>
                this.using.fetchAdd(1)
                return conn
            case None =>
                throw SqlException("获取数据库连接超时：连接池已满或连接不可用")
        }
    }

    public func put(conn: Client): Unit {
        this.queue.add(conn, Duration.second * 30)
        this.using.fetchAdd(-1)
    }

    public func del(client: Client): Unit {
        this.using.fetchAdd(-1)
        this.untrack(client)
    }

    // 进行扩容
    public func tryConnMore() {
        synchronized(this.mtx) {
            if ((this.queue.size + this.using.load()) >= this.config.poolMaxCount) {
                return;
            }
            this.queue.add(this.newClient())
        }
    }

    // 关闭所有连接（数据源重建/重连时调用）
    public func close(): Unit {
        synchronized(this.allMtx) {
            for (i in 0..this.allClients.size) {
                try {
                    this.allClients[i].close()
                } catch (_: Exception) {}
            }
            this.allClients.clear()
        }
    }

    protected func untrack(client: Client): Unit {
        synchronized(this.allMtx) {
            var i = 0
            while (i < this.allClients.size) {
                if (this.allClients[i].id == client.id) {
                    this.allClients.remove(i..i + 1)
                    return
                }
                i++
            }
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

        let c = Client(connect, this)
        synchronized(this.allMtx) {
            this.allClients.add(c)
        }
        return c
    }

    public func size(): Int64 {
        return this.queue.size
    }
}
