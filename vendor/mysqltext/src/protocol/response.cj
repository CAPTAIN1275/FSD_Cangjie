/**
 * 这里定义通用的mysql协议包
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
*/
package mysql.protocol

import std.collection.*

/**
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
 */
public open class Response {
    
}

public open class MoreDataResponse <: Response {
    public let data: Array<Byte>

    public init(data: Array<Byte>) {
        this.data = data
    }
}

public interface SetBinaryResponse {
    func setBinary(packet: Array<Byte>): Unit
}