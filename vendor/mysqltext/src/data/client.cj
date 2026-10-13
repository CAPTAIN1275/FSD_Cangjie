package mysql.data

import mysql.net
import mysql.protocol.*
import std.collection.ArrayList
import std.sync.AtomicInt64

// 全局自增 id，用于连接池追踪并关闭所有连接（Client 不是 Hashable）
let clientIdSeq = AtomicInt64(0)

/**
 * mysql 客户端功能描述
 * 每个连接对应一个Client对象
 */
public class Client {
    // 唯一 id
    public let id: Int64
    // 和数据库的链接
    protected let socket: net.Socket
    // 连接池管理
    protected let pool: Pool

    // 记录是否在事务中
    var inTransaction: Bool = false

    public init(socket: net.Socket, pool: Pool) {
        this.id = clientIdSeq.fetchAdd(1)
        this.socket = socket
        this.pool = pool
    }

    public func beginTransaction() {
        this.inTransaction = true
    }

    public func closeTransaction() {
        this.inTransaction = false
    }

    public func release() {
        if (!this.inTransaction) {
            // 不在事务中, 才可以放回连接池
            // 在事务中, 需要先关闭事务
            // 坏连接（读写出错）不能归还池，否则会污染后续操作，直接关闭并丢弃
            if (this.socket.broken) {
                this.socket.close()
                this.pool.del(this)
            } else {
                this.pool.put(this)
            }
        }
    }

    /**
     * 重置连接, 链接需要重新初始化
     */
    public func reset() {
    }

    // 关闭底层连接
    public func close(): Unit {
        this.socket.close()
    }

    /**
     * 执行一个命令
     * @param CommandType command 命令
     * @param arg 参数
     */
    public func command(command: CommandType, arg: String) {
        this.socket.command(command.value(), arg)
    }

    /**
     * 执行一个命令
     * @param CommandType command 命令
     * @param arg 参数
     */
    public func command(command: CommandType, arg: UInt32) {
        this.socket.command(command.value(), arg)
    }

    public func read(): Array<Byte> {
        this.socket.read()
    }

    // 读取结束, 如果发送错误直接抛出异常
    public func readUntilEOF() {
        do {
            match (this.socket.response()) {
                case err: ErrResponse =>
                    this.reset()
                    throw err.toException()
                case res: EofResponse => return;
                case _ => continue
            }
        } while (true)
    }

    // 读取一个OkResponse
    public func okResponse(): OkResponse {
        return match (this.socket.response()) {
            case res: OkResponse => res
            case err: ErrResponse =>
                this.reset()
                throw err.toException()
            case _ => throw Exception("not ok response")
        }
    }

    public func response(res: SetBinaryResponse) {
        let pack = this.read()
        return match (pack[0]) {
            case 0x00 => res.setBinary(pack)
            case 0xFF =>
                this.reset()
                throw ErrResponse(pack).toException()
            case _ => throw Exception("not MoreDataResponse response")
        }
    }

    public func writeExecutePacket(data: Array<Byte>) {
        this.socket.sequence = 0
        this.socket.write(data)
    }
}
