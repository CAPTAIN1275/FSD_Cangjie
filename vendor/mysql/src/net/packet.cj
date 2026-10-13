package mysql.net

import std.net.TcpSocket
import mysql.errors.*
import std.collection.ArrayList
import mysql.protocol
import std.database.sql

const maxPacketSize = 1 << 24 - 1

/**
 * 信息帧处理, 处理mysql协议的包
 * 每次读取、写都是以一个包为单位
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html#sect_protocol_basic_packets_sequence_id
 */
public open class Packet {
    protected let buff: Buff

    // 交互时报文的顺序; 每一个命令都是一个新的开始
    public var sequence: UInt8 = 0

    public let socket: TcpSocket

    public init(address: String, port: UInt16) {
        try {
            this.socket = TcpSocket(address, port)
            this.socket.connect()
            this.buff = Buff(this.socket)
        } catch (e: Exception) {
            throw sql.SqlException("发起连接失败, 请检查mysql server是否已经启动, 或者链接配置是否正确!")
        }
    }

    /**
     * 读取一个完整的包
     */
    public func read(): Array<Byte> {
        var prevData = ArrayList<Byte>()

        do {
            let header = this.buff.readNext(4)
            let pktLen = Int64(UInt32(header[0]) | UInt32(header[1]) << 8 | UInt32(header[2]) << 16)
            if (pktLen == 0) {
                throw IOException("无法正常读取信息包, 读取信息头长度为 0")
            }
            // if (header[3] != this.sequence) {
            //     throw SequenceException("序列 ID 不正确; 本地(${sequence}) 返回[3](${header[3]})")
            // }

            // 这里无法自动递增和重置
            if (this.sequence == 255) {
                this.sequence = 0
            } else {
                //trace("readPacket: sequence++ = ${this.sequence + 1}")
                this.sequence++
            }

            let body = this.buff.readNext(pktLen)
            if (pktLen < 16777215) {
                // 无需读取下一个拆分的包
                if (prevData.size == 0) {
                    //trace("read packet: ${body}")
                    return body
                }
            }

            prevData.add(all:body)
        } while (true)

        return prevData.toArray()
    }

    /**
     * 写入一个完整的包, 补充长度和序列信息
     * 仓颉内存块的复用没想到优化, 当前只能每次创建新的
     *
     * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_packets.html#sect_protocol_basic_packets_packet
     */
    public func write(bytes: Array<Byte>) {
        var data = bytes
        // 剩余发送的字节数
        var pktLen = data.size
        
        while (true) {
            var wData = ArrayList<Byte>(4, {_=> 0})
            var size: Int = 0
            if (pktLen >= maxPacketSize) {
                wData[0] = 0xff
                wData[1] = 0xff
                wData[2] = 0xff
                size = maxPacketSize
            } else {
                // & 0xFF 是为了防止溢出
                wData[0] = UInt8(pktLen & 0xFF)
                wData[1] = UInt8((pktLen >> 8) & 0xFF)
                wData[2] = UInt8((pktLen >> 16) & 0xFF)
                size = pktLen
            }
            wData[3] = this.sequence
            wData.add(all:data[..size].toArray())
            //trace("write packet: ${wData}")
            this.buff.write(wData.toArray())
            // TODO 这里应该需要坚持发送数量的
            // write 返回值无法使用
            //trace("writePacket: sequence++ = ${this.sequence + 1}")
            // 与 read() 一致做回绕，避免 UInt8 溢出抛 OverflowException
            if (this.sequence == 255) {
                this.sequence = 0
            } else {
                this.sequence++
            }

            if (size != maxPacketSize) {
                return
            }
            pktLen -= size
            data = data[size..]
            continue
        }
    }

    // 底层连接是否已损坏（读写出错）
    public prop broken: Bool {
        get() {
            this.buff.broken
        }
    }

    // 关闭底层 socket
    public func close(): Unit {
        try {
            this.socket.close()
        } catch (_: Exception) {}
    }
}
