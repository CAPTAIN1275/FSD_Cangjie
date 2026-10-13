/**
 * 这里定义通用的mysql协议包
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
*/
package mysql.protocol

import std.collection.*

/**
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_ok_packet.html
 */
public class OkResponse <: Response {
    public var affected_rows: UInt64

    public var last_insert_id: UInt64

    public var status_flags: UInt16

    public var warnings: UInt16 = 0

    public var info: String = ""

    public init(pack: Array<Byte>) {
        var pos = 1
        var n = 0
        // 受影响的行
        (affected_rows, _, n) = readLengthEncodedInteger(pack[pos..])
        pos += n

        // 新插入数据的ID
        (last_insert_id, _, n) = readLengthEncodedInteger(pack[pos..])
        pos += n

        // server_status [2 bytes]
        this.status_flags = littleEndianToUInt16(pack[pos..pos + 2])
        pos += 2

        this.warnings = littleEndianToUInt16(pack[pos..pos + 2])
        pos += 2
        this.info = String.fromUtf8(pack[pos..])
    }
}
