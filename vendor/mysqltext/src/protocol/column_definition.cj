package mysql.protocol

import std.database.sql
import std.collection.ArrayList
import std.binary.*
import std.time.DateTime

/*
 * Column 读取器
 * https://dev.mysql.com/doc/dev/mysql-server/latest/page_protocol_com_query_response_text_resultset_column_definition.html
 */
public class ColumnDefinition {
    /*目录名*/
    public var _catalog: String
    /*数据库名*/
    public var _database: String
    /*表名*/
    public var _table: String
    /*原始表名*/
    public var _originalTable: String
    /*字段名*/
    public var _name: String
    /*原始字段名*/
    public var _originalName: String
    /*填充值*/
    public var _padding: Byte
    /*字符串编码*/
    public var _charset: Byte
    /*字段长度*/
    public var _columnLength: UInt32
    /*字段类型*/
    public var _columnType: Byte
    /*字段标志*/
    public var _flags: UInt16
    /*浮点型精度*/
    public var _decimals: Byte

    public init(data: Array<Byte>) {
        var pos = 0
        (this._catalog, pos) = data.readLengthEncodedString(pos)

        (this._database, pos) = data.readLengthEncodedString(pos)

        (this._table, pos) = data.readLengthEncodedString(pos)

        (this._originalTable, pos) = data.readLengthEncodedString(pos)

        (this._name, pos) = data.readLengthEncodedString(pos)

        (this._originalName, pos) = data.readLengthEncodedString(pos)

        this._padding = data[pos]
        pos++

        this._charset = data[pos]
        pos += 2


        this._columnLength = littleEndianToUInt32(data[pos..pos + 4])
        pos += 4


        this._columnType = data[pos]

        this._flags = littleEndianToUInt16(data[pos..pos + 2])
        pos += 2
        this._decimals = data[pos]
    }
}