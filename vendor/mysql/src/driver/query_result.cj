package mysql.driver

import std.database.sql
import mysql.data
import mysql.protocol
import std.collection.ArrayList

/**
 * 执行 Select 语句产生的结果接口
 */
public open class QueryResult <: sql.QueryResult {
    protected let client: data.Client

    // 这里是 mysql 原始的返回, 不是 sql 接口约束的，需要做转换
    protected let columnsDefintion: Array<protocol.ColumnDefinition>

    public init(client: data.Client) {
        this.client = client

        let cols = ArrayList<protocol.ColumnDefinition>()
        let resLen = protocol.StmtColumnCount(client.read())
        for (_ in 0..resLen) {
            cols.add(protocol.ColumnDefinition(client.read()))
        }
        this.columnsDefintion = cols.toArray()

        //丢弃Column Eof包
        client.read()
    }

    public prop columnInfos: Array<sql.ColumnInfo> {
        get() {
            let columns = ArrayList<sql.ColumnInfo>()
            for (ret in this.columnsDefintion) {
                let info = ColumnInfo()
                info._name = ret._name
                info._field = ret._columnType
                info._length = ret._columnLength
                info._decimals = ret._decimals
                info._flags = ret._flags
                info._charSet = ret._charset

                columns.add(info)
            }
            return columns.toArray()
        }
    }

    // todo 和 语言级别类型直接映射
    public func readRow(): (Array<Array<Byte>>, Bool) {
        let data = this.client.read()

        if (data[0] != 0x00) {
            if (data[0] == 0xFE && data.size == 5) {
                return (Array<Array<Byte>>(), false)
            }
            throw protocol.ErrResponse(data).toException()
        }

        return (protocol.BinaryResultset(data, this.columnsDefintion).row, true)
    }

    @Deprecated
    public open func next(_: Array<sql.SqlDbType>): Bool {
        return false
    }

    private var row = Array<Array<Byte>>()

    public func next(): Bool {
        let (row, has) = this.readRow()
        if (!has) {
            return false
        }
        this.row = row
        return true
    }

    public func get<T>(index: Int): T {
        fromBinary<T>(row[index])
    }

    public func getOrNull<T>(index: Int): ?T {
        let bs = row[index]
        if(bs.size == 0) {
            return None
        }
        return get<T>(index)
    }

    public func isClosed(): Bool {
        false
    }

    public func close(): Unit {
        this.row = Array<Array<Byte>>()
    }
}
