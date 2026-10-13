package mysql.data

import std.collection.concurrent.BlockingQueue
import std.net.TcpSocket
import std.database.sql.SqlException
import std.sync.{AtomicInt64, ReentrantMutex}
import mysql.net.Socket

/**
 * 管理链接池
 */
public interface Pool {
    func get(): Client
    func put(client: Client): Unit
    func del(client: Client): Unit
    func close(): Unit
}
