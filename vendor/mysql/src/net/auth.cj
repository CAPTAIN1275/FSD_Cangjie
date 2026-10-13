package mysql.net

import std.net.TcpSocket
import mysql.protocol
import std.database.sql
import std.net.*
import std.collection.*
import std.convert.*
import std.binary.*
import stdx.crypto.digest.*
import stdx.crypto.keys.*

/**
 * 登录认证相关逻辑
 */
public class Auth {
    public let socket: Socket
    // 地址, 只能是IP或域名
    var address: String = "127.0.0.1"
    var port: UInt16 = 3306

    var username: String = "root"
    var password: String = "root"
    var database: String = "test"

    var tls: Bool = false

    public init(socket: Socket) {
        this.socket = socket
    }

    public func setAddress(address: String): This {
        this.address = address
        return this
    }

    public func setPort(port: UInt16): This {
        this.port = port
        return this
    }

    public func setUser(user: String): This {
        this.username = user
        return this
    }

    public func setPassword(password: String): This {
        this.password = password
        return this
    }

    public func setDatabase(database: String): This {
        this.database = database
        return this
    }

    public func setTls(): This {
        this.tls = true
        return this
    }

    /**
     * 认证逻辑
     * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_handshake.html
     */
    public func connect() {
        let handshake = protocol.Handshake(this.socket.read())

        // 是否需要 ssl
        // 性能优先, 未支持 ssl; 建议使用ip安全组+强密码保证安全

        let authData = handshake.authData
        // 准备发送认证数据包
        let authResp = match (handshake.authPluginName) {
            case "caching_sha2_password" => sha256(authData, password)
            case "mysql_native_password" => sha1(authData, password)
            case _ => throw sql.SqlException("不支持的认证方式 ${handshake.authPluginName}")
        }

        let handshakeResponse = protocol.HandshakeResponse(this.address, this.username, this.database)
        handshakeResponse.setFlags(handshake.capability_flags_1)
        this.socket.write(handshakeResponse.toResponseProtocol41(authResp, handshake.authPluginName))

        // 检查服务器是否认证成功
        this.handleAuthResult(authData, handshake.authPluginName)
    }
    /**
     * 对于客户端发送到服务器的大多数命令，服务器会返回以下数据包之一作为响应
     * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
     */
    public func authResponse(pack: Array<Byte>): protocol.Response {
        return match (pack[0]) {
            case 0x00 => protocol.OkResponse(pack)
            case 0x01 => protocol.AuthSwitchResponse(pack)
            case 0xFE => protocol.EofResponse(pack)
            case 0xFF => protocol.ErrResponse(pack)
            case _ => throw sql.SqlException("mysql server 下发的协议包含未知类型, 标识位: ${pack[0]}")
        }
    }

    public func handleAuthResult(authData: Array<Byte>, plugin: String): Unit {
        match (this.authResponse(this.socket.read())) {
            case err: protocol.ErrResponse => throw err.toException()
            case switch: protocol.AuthSwitchResponse => match (plugin) {
                case "caching_sha2_password" => match (switch.status) {
                    case 0x03 => 
            
                        this.socket.read()
                    case 0x04 =>
                        if (this.tls) {
                            throw sql.SqlException("TODO 不支持的tls")
                        } else {
                            this.socket.write([protocol.CommandType.InitDB.value()])// InitDB
                            var pubKeyString: String = ""
                            match (this.socket.response()) {
                                case res: protocol.MoreDataResponse => pubKeyString = String.fromUtf8(res.data[1..])
                                case err: protocol.ErrResponse => throw err.toException()
                                case _ => throw Exception("init db error")
                            }
                            let pubKey = RSAPublicKey.decodeFromPem(pubKeyString)
                            this.socket.write(encryptPassword(this.password, authData, pubKey))

                            this.socket.read()
                        }
                    case _ => throw sql.SqlException("caching_sha2_password认证时, 响应包status不正确")
                }
                case "sha256_password" => match (switch.status) {
                    case 0x00 => this.socket.read()
                    case _ => throw sql.SqlException("sha256_password认证时, 响应包status不正确")
                }
                case _ => throw sql.SqlException("登录认证失败, 当前支持了caching_sha2_password、sha256_password")
            }

            case _ => return; // protocol.OkResponse => 
        }
    }
}
