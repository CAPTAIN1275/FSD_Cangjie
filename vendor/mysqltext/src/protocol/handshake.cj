package mysql.protocol

import std.io.*
import std.collection.*
import std.binary.*
import std.database.sql

/**
 * 普通握手
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake_v10.html
 */
public class Handshake {
    // int<1>	protocol version	Always 10
    public let protocolVersion: Byte
    // string<NUL>	server version	human readable status information
    public var serverVersion: String = ""
    // int<4>	thread id	a.k.a. connection id
    public var threadId: UInt32 = 0
    // string[8]	auth-plugin-data-part-1	first 8 bytes of the plugin provided data (scramble)
    public let authPluginDataPart1: String
    // int<1>	filler	0x00 byte, terminating the first part of a scramble
    public let filler: Byte
    // int<2>	capability_flags_1	The lower 2 bytes of the Capabilities Flags
    public var capability_flags_1: UInt32
    // int<1>	character_set	default server a_protocol_character_set, only the lower 8-bits
    public let character_set: Byte
    // int<2>	status_flags	SERVER_STATUS_flags_enum
    public let status_flags: UInt16
    // int<2>	capability_flags_2	The upper 2 bytes of the Capabilities Flags
    public let capability_flags_2: UInt16
    // string[10]	reserved	10 bytes of reserved data, all 0x00
    public var reserved: String = ""
    // $length	auth-plugin-data-part-2	Rest of the plugin provided data (scramble), $len=MAX(13, length of auth-plugin-data - 8)
    public let authPluginDataPart2: String
    // string[NUL]	auth-plugin-name	name of the plugin provided as the part of the handshake
    public let authPluginName: String

    public init(data: Array<Byte>) {
        protocolVersion = data[0]
        // 检查 1 byte 协议版本
        if (protocolVersion < 10) {
            throw sql.SqlException("不支持的版本号, 当前支持协议号为 10, 当前为 {protocolVersion}")
        } else if (data[0] == 255) {
            throw ErrResponse(data).toException()
        }

        var pos: Int = 0
        for (i in 1..=data.size) {
            // null 结尾之前是服务器版本号
            // 连接id[4字节]
            if (data[i] == 0) {
                pos = i + 1 + 4 // i = 1; 开头;
                serverVersion = String.fromUtf8(data[1..i])
                threadId = littleEndianToUInt32(data[i..i + 4])
                break
            }
        }

        // 随机数, 用于后面密码认证; 8 + 1（0x00表示结束)
        authPluginDataPart1 = String.fromUtf8(data[pos..pos + 8])
        filler = data[pos + 1]
        pos += 8 + 1

        // 与客户端协商通讯方式: 65535
        capability_flags_1 = littleEndianToUInt32(data[pos..pos + 2])
        pos += 2

        // 编码格式 [1 byte]
        character_set = data[pos + 1]
        // 服务器状态 [2 bytes]
        status_flags = UInt16.readLittleEndian(data[pos..pos + 2])
        // 扩展的协议，数据库提供的功能 (upper 2 bytes) [2 bytes]
        capability_flags_2 = UInt16.readLittleEndian(data[pos..pos + 2])
        // 身份验证插件长度 [1 byte]
        // var authDataLen = data[pos + 1]
        // 保留字节 (all [00]) [10 bytes]
        pos += 1 + 2 + 2 + 1 + 10

        // 随机数（第二部分）
        authPluginDataPart2 = String.fromUtf8(data[pos..pos + 12])
        pos += 13

        // EOF if version (>= 5.5.7 and < 5.5.10) or (>= 5.6.0 and < 5.6.2)
        // \NUL otherwise
        var end: Int = -1
        for (i in pos..=data.size) {
            if (data[i] == 0) {
                end = i
                break
            }
        }

        if (end != -1) {
            authPluginName = String.fromUtf8(data[pos..end])
        } else {
            authPluginName = String.fromUtf8(data[pos..])
        }
    }

    protected prop authData: Array<Byte> {
        get() {
            var temp = ArrayList<Byte>()
            temp.add(all:this.authPluginDataPart1)
            temp.add(all:this.authPluginDataPart2)
            return temp.toArray()
        }
    }
}
