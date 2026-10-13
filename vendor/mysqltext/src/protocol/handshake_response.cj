package mysql.protocol

import std.collection.*

// MySQL 协议使用的 capabilities 标志位掩码的值
// 掩码方式写进4 个位的数据里
// https://dev.mysql.com/doc/dev/mysql-server/latest/group__group__cs__capabilities__flags.html
const ClientLongPassword: UInt32 = 1
// const ClientFoundRows: UInt32 = 2 << 0
const ClientLongFlag: UInt32 = 2 << 1
const ClientConnectWithDB: UInt32 = 2 << 2
// const ClientNoSchema: UInt32 = 2 << 3
// const ClientCompress: UInt32 = 2 << 4
// const ClientODBC: UInt32 = 2 << 5
const ClientLocalFiles: UInt32 = 2 << 6
// const ClientIgnoreSpace: UInt32 = 2 << 7
const ClientProtocol41: UInt32 = 2 << 8
// const ClientInteractive: UInt32 = 2 << 9
// const ClientSSL: UInt32 = 2 << 10
// const ClientIgnoreSIGPIPE: UInt32 = 2 << 11
const ClientTransactions: UInt32 = 2 << 12
// const ClientReserved: UInt32 = 2 << 13
const ClientSecureConn: UInt32 = 2 << 14
// const ClientMultiStatements: UInt32 = 2 << 15
const ClientMultiResults: UInt32 = 2 << 16
// const ClientPSMultiResults: UInt32 = 2 << 17
const ClientPluginAuth: UInt32 = 2 << 18
const ClientConnectAttrs: UInt32 = 2 << 19
const ClientPluginAuthLenEncClientData: UInt32 = 2 << 20
// const ClientCanHandleExpiredPasswords: UInt32 = 2 << 21
// const ClientSessionTrack: UInt32 = 2 << 22
// const ClientDeprecateEOF: UInt32 = 2 << 23

// 链接属性
const connAttrClientName = "_client_name"
const connAttrClientNameValue = "Cj-MySQL-Driver"
const connAttrOS = "_os"
const connAttrOSValue = "darwin"
const connAttrPlatform = "_platform"
const connAttrPlatformValue = "arm64"
const connAttrPid = "_pid"
const connAttrServerHost = "_server_host"

/*
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake_response.html
 */
public class HandshakeResponse {
    // MySQL 协议使用的 capabilities 标志位掩码的值
    // 直接设置了部分掩码默认值
    protected var capability_flags_1: UInt32 = ClientProtocol41 | ClientSecureConn | ClientLongPassword |
        ClientTransactions | ClientLocalFiles | ClientPluginAuth | ClientMultiResults | ClientConnectAttrs
    protected let user: String
    protected let database: String
    protected let address: String

    public init(address: String, user: String, database: String) {
        this.user = user
        this.database = database
        this.address = address
    }

    public func setFlags(v: UInt32) {
        this.capability_flags_1 = this.capability_flags_1 | v & ClientLongFlag
    }

    /**
     * 支持 4.1+ 客户端发送的握手响应包CLIENT_PROTOCOL_41 Capabilities Flags 标志，
     * 如果服务器在其 Protocol：：Handshake 中宣布。
     * 否则（与旧服务器通信）必须使用 Protocol：：HandshakeResponse320 数据包。
     */
    public func toResponseProtocol41(authResp: Array<UInt8>, plugin: String): Array<Byte> {
        // https://dev.mysql.com/doc/dev/mysql-server/latest/group__group__cs__capabilities__flags.html
        var clientFlags = this.capability_flags_1

        // 对密码长度进行固定编码
        var authRespLEIBuf = ArrayList<UInt8>()
        var authRespLEI = appendLengthEncodedInteger(authRespLEIBuf, authResp.size)

        if (authRespLEI.size > 1) {
            clientFlags |= ClientPluginAuthLenEncClientData
        }

        var pktLen = 4 + 4 + 1 + 23 + this.user.size + 1 + authRespLEI.size + authResp.size + 21 + 1

        if (this.database.size > 0) {
            clientFlags |= ClientConnectWithDB
            pktLen += this.database.size + 1
        }
        let encodedAttributes = this.encodeConnectionAttributes()
        // 对属性进行编码
        var connAttrsLEIBuf = ArrayList<UInt8>()
        var connAttrsLen = encodedAttributes.size
        var connAttrsLEI = appendLengthEncodedInteger(connAttrsLEIBuf, connAttrsLen)
        pktLen += connAttrsLEI.size + encodedAttributes.size

        let data: ArrayList<Byte> = ArrayList<Byte>(pktLen, {_=>0})

        // ClientFlags [32 bit]
        data[0] = truncateToByte(clientFlags)
        data[1] = truncateToByte(clientFlags >> 8)
        data[2] = truncateToByte(clientFlags >> 16)
        data[3] = truncateToByte(clientFlags >> 24)

        // MaxPacketSize [32 bit] (none)
        data[4] = 0x00
        data[5] = 0x00
        data[6] = 0x00
        data[7] = 0x00

        // Collation ID [1 byte]
        let cname = "utf8mb4_general_ci"

        data[8] = UInt8(collations[cname])

        // Filler [23 bytes] (all 0x00)
        var pos = 9
        while (pos < 9 + 23) {
            pos++
            data[pos] = 0
        }

        // SSL 不支持
        if (this.user.size > 0) {
            for (s in this.user.toArray()) {
                data[pos] = s
                pos++
            }
        }
        data[pos] = 0x00
        pos++

        pos += listCopyList(data, pos, authRespLEI, 0, authRespLEI.size)
        pos += listCopyArray(data, pos, authResp, 0, authResp.size)

        if (this.database.size > 0) {
            pos += listCopyString(data, pos, this.database)
            data[pos] = 0x00
            pos++
        }

        pos += listCopyString(data, pos, plugin)
        data[pos] = 0x00
        pos++

        // Connection Attributes
        pos += listCopyList(data, pos, connAttrsLEI, 0, connAttrsLEI.size)
        pos += listCopyString(data, pos, encodedAttributes)

        // 开始发送数据包
        return data.toArray()
    }

    func encodeConnectionAttributes(): String {
        var connAttrsBuf = ArrayList<UInt8>()

        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrClientName)
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrClientNameValue)
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrOS)
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrOSValue) // TODO Win32, Linux, Darwin
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrPlatform)
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrPlatformValue) // TODO amd64, arm 平台架构
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrPid)
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, "${Thread.currentThread.id}")

        // 只支持 tpc host
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, connAttrServerHost)
        connAttrsBuf = appendLengthEncodedString(connAttrsBuf, this.address)

        return String.fromUtf8(connAttrsBuf.toArray())
    }

    func appendLengthEncodedString(sb: ArrayList<UInt8>, s: String): ArrayList<UInt8> {
        var b = appendLengthEncodedInteger(sb, s.size)
        let ss = s.toArray()
        b.add(all:ss)
        return b
    }
}
