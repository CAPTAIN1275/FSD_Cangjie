package mysql.net

import std.net.TcpSocket
import mysql.protocol
import std.database.sql.SqlException
import std.collection.ArrayList

/**
 * 和 mysql server 通信的 socket
 * 功能颗粒度在功能上 比较粗，比如：
 *  - 登录认证
 *  - 命令封装
 */
public class Socket <: Packet {
    public init(address: String, port: UInt16) {
        super(address, port)
    }

    /**
     * 认证逻辑
     * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake.html
    */
    public func auth(): Auth {
        return Auth(this)
    }

    /**
     * 对于客户端发送到服务器的大多数命令，服务器会返回以下数据包之一作为响应
     * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
     */
    public func response(): protocol.Response {
        let pack = this.read()
        return match (pack[0]) {
            case 0x00 => protocol.OkResponse(pack)
            case 0xFF => protocol.ErrResponse(pack)
            case 0xFE => protocol.EofResponse(pack)
            case _ => protocol.MoreDataResponse(pack)
        }
    }

    /**
     * 执行一个命令
     * @param CommandType command 命令
     * @param arg 参数
    */
    public func command(command: Byte, arg: String) {
        let packet = ArrayList<Byte>([command])
        packet.add(all:arg.toArray())
        this.sequence = 0

        this.write(packet.toArray())
    }

    public func command(command: Byte, arg: UInt32) {
        let packet = ArrayList<Byte>([command])
        packet.add(all:protocol.StatementId(arg))
        this.sequence = 0

        this.write(packet.toArray())
    }


    public func command(command: Byte) {
        let packet = ArrayList<Byte>([command])
        this.sequence = 0

        this.write(packet.toArray())
    }
}
