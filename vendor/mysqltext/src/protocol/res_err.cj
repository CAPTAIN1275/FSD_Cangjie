/**
 * 这里定义通用的mysql协议包
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_response_packets.html
 */
package mysql.protocol

import std.collection.*
import std.database.sql.SqlException

/**
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_basic_err_packet.html
 */
public class ErrResponse <: Response {
    protected var _errorCode: Int64

    protected var _serverStateMarker: Byte = 0

    protected var _sqlState: String = ""

    protected var _errMessage: String = ""

    public init(pack: Array<Byte>) {
        _errorCode = littleEndianToInt64(pack[1..3])
        _serverStateMarker = pack[3]

        var pos = 3
        if (pack[3] == 0x23) {
            _sqlState = String.fromUtf8(pack[4..9])
            pos = 9
        }
        
        _errMessage = String.fromUtf8(pack[pos..])
    }

    public prop message: String {
        get() {
            _errMessage
        }
    }

    public func toException(): SqlException {
        return SqlException(_errMessage, _sqlState, _errorCode)
    }
}
