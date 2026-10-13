/**
 * 这里定义通用的mysql协议包
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
*/
package mysql.protocol

import std.collection.*

/**
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_eof_packet.html
 */
public class EofResponse <: Response {
    public init(_: Array<Byte>) {

    }
}
