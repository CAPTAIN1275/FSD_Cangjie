package mysql.protocol

/**
 * 身份验证方法 Switch Response Packet，其中包含 Protocol：：OldAuthSwitchRequest： 数据包中请求的身份验证方法生成的响应数据。
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_connection_phase_packets_protocol_auth_switch_response.html
 * 返回
 *  Protocol：：AuthMoreData：、ERR_Packet 或 OK_Packet
*/
public class AuthSwitchResponse <: Response {
    // 0 可能旧的模式
    // 0x03 cachingSha2PasswordFastAuthSuccess
    // 0x04 cachingSha2PasswordPerformFullAuthentication
    public var status: Byte = 0x00
    public var data: Array<Byte> = []

    public init(pack: Array<Byte>) {
        if (pack.size != 0) {
            this.status = pack[1]

            this.data = pack[1..]
        }
    }
}