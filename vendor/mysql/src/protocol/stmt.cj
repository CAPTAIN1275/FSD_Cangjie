package mysql.protocol

import std.database.sql
import std.collection.ArrayList
import std.binary.*
import std.time.DateTime

/*
 * StmtColumnCount
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_com_query_response.html
 */
public func StmtColumnCount(pack: Array<Byte>) {
    UInt32(readLengthEncodedUInt64(pack))
}

/**
 * 二进制协议 Resultset 类似于文本 Resultset。
 * 它只包含 Binary Protocol Resultset Row 格式的行。
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_binary_resultset.html
 */
public class Resultset <: Response {
    // 0x00：正常：被 cli_read_prepare_result 忽略
    public var statement_id: UInt32

    public init(pack: Array<Byte>) {
        if (pack[0] == 0x00) {
            throw ErrResponse(pack).toException()
        }
        this.statement_id = UInt32.readLittleEndian(pack[1..5])
    }
}

/**
 * 把 statement_id 转换为二进制包
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_com_stmt_close.html
 */
public func StatementId(statement_id: UInt32): Array<Byte> {
    return [
        UInt8(statement_id & 0xFF),
        UInt8((statement_id >> 8) & 0xFF),
        UInt8((statement_id >> 16) & 0xFF),
        UInt8((statement_id >> 24) & 0xFF)
    ]
}

/*
 * 如果 COM_STMT_PREPARE 成功，它会发送一个 COM_STMT_PREPARE_OK
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_com_stmt_prepare.html#sect_protocol_com_stmt_prepare_response
 */
public class StmtPrepareResposne <: SetBinaryResponse {
    // 0x00：正常：被 cli_read_prepare_result 忽略
    public var statement_id: UInt32 = 0
    // 列数 
    public var num_columns: UInt16 = 0
    // 参数数量
    public var num_params: UInt16 = 0
    // [00] 填料
    public var reserved_1: UInt8 = 0
    // 警告数量
    public var warning_count: UInt16 = 0

    public func setBinary(packet: Array<Byte>): Unit {
        this.statement_id = UInt32.readLittleEndian(packet[1..5])
        this.num_columns = UInt16.readLittleEndian(packet[5..7])
        this.num_params = UInt16.readLittleEndian(packet[7..9])
        this.reserved_1 = UInt8(packet[9])
        this.warning_count = UInt16.readLittleEndian(packet[10..12])
    }
}

var maxAllowedPacket: UInt32 = 1 << 24 - 1
let minPktLen = 10
/**
 * 生成 stmt 参数包
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_com_stmt_execute.html
 */
public func StmtExecute(params: Array<SqlData>, stmtID: UInt32): Array<Byte> {
    var longDataSize = Int64(maxAllowedPacket) / (params.size + 1)
    if (longDataSize < 64) {
        longDataSize = 64
    }

    var data: ArrayList<UInt8>
    if (params.size == 0) {
        data = ArrayList<UInt8>(Array<UInt8>(minPktLen, repeat: 0))
    } else {
        data = ArrayList<UInt8>(minPktLen, {_ => 0})
    }

    // command [1 byte]
    data[0] = CommandType.StmtExecute.value()

    // statement_id [4 bytes]
    data[1] = truncateToByte(stmtID)
    data[2] = truncateToByte(stmtID >> 8)
    data[3] = truncateToByte(stmtID >> 16)
    data[4] = truncateToByte(stmtID >> 24)

    // flags (0: CURSOR_TYPE_NO_CURSOR) [1 byte]
    data[5] = 0x00

    // iteration_count (uint32(1)) [4 bytes]
    data[6] = 0x01
    data[7] = 0x00
    data[8] = 0x00
    data[9] = 0x00

    if (params.size > 0) {
        var pos = minPktLen
        // 掩码计算
        var maskPos = pos
        var nullMask = ArrayList<UInt8>()
        let maskLen = (params.size + 7) / 8
        let typesLen = 1 + 2 * params.size
        if (pos + maskLen + typesLen >= data.size) {
            data.add(all: Array<UInt8>(maskLen + 1, repeat: 0))
            pos += maskLen
        } else {
            data.add(all: Array<UInt8>(nullMask.size + 1, repeat: 0))
            pos += maskLen
        }

        // 新参数边界 1 [1 byte]
        data[pos] = 0x01

        // 每个参数类型分配两个字节的空间 [args.size * 2 bytes]
        var paramTypes = ArrayList<UInt8>()
        // 记录容量 [n bytes]
        var paramValues = ArrayList<UInt8>()

        // null_bitmap
        for (i in 0..params.size) {
            match (params[i]) {
                case v: SqlNull =>     
                    let nullIndex = i / 8
                    var nullValue = data[maskPos + nullIndex]
                    nullValue |= 1<< ((UInt8(i & 0xFF)) & 7)
                    data[maskPos + nullIndex] = nullValue
                case _ => continue
            }
        }

        for (arg in params) {
            arg.writeSqlType(data)
        }
        for (arg in params) {
            arg.writeSqlValue(data)
        }
    }

    data.toArray()
}
