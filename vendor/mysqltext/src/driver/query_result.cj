package mysql.driver

import std.database.sql
import mysql.data
import mysql.protocol
import std.collection.ArrayList

/**
 * 执行 Select 语句产生的结果接口（文本协议）
 * 构造时一次性读完所有行并归还连接，之后从内存读取，避免连接被并发复用。
 */
public open class QueryResult <: sql.QueryResult {
    protected let columnsDefintion: Array<protocol.ColumnDefinition>
    protected let rows: Array<Array<Array<Byte>>>
    protected var idx: Int64 = -1
    protected var row: Array<Array<Byte>> = Array<Array<Byte>>(0, repeat: Array<Byte>(0, repeat: 0))

    public init(client: data.Client) {
        let cols = ArrayList<protocol.ColumnDefinition>()
        let resLen = protocol.StmtColumnCount(client.read())
        for (_ in 0..resLen) {
            cols.add(protocol.ColumnDefinition(client.read()))
        }
        this.columnsDefintion = cols.toArray()

        // 丢弃 Column EOF 包
        client.read()

        // 一次性读完所有行，随后立即归还连接
        let all = ArrayList<Array<Array<Byte>>>()
        try {
            while (true) {
                let (r, has) = readTextRow(client)
                if (!has) { break }
                all.add(r)
            }
        } finally {
            try { client.release() } catch (_: Exception) {}
        }
        this.rows = all.toArray()
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

    public func readRow(): (Array<Array<Byte>>, Bool) {
        if (this.idx + 1 >= this.rows.size) {
            return (Array<Array<Byte>>(0, repeat: Array<Byte>(0, repeat: 0)), false)
        }
        this.idx++
        return (this.rows[this.idx], true)
    }

    @Deprecated
    public open func next(_: Array<sql.SqlDbType>): Bool {
        return false
    }

    public func next(): Bool {
        let (r, has) = this.readRow()
        if (!has) {
            return false
        }
        this.row = r
        return true
    }

    public func get<T>(index: Int): T {
        fromBinary<T>(row[index])
    }

    public func getOrNull<T>(index: Int): ?T {
        let bs = row[index]
        if (bs.size == 0) {
            return None
        }
        return get<T>(index)
    }

    public func isClosed(): Bool {
        return false
    }

    public func close(): Unit {
        this.row = Array<Array<Byte>>(0, repeat: Array<Byte>(0, repeat: 0))
    }
}

// 读一行文本协议结果；返回 (字段字节, 是否还有)
func readTextRow(client: data.Client): (Array<Array<Byte>>, Bool) {
    let data = client.read()
    if (data.size == 0) {
        return (Array<Array<Byte>>(0, repeat: Array<Byte>(0, repeat: 0)), false)
    }
    if (data[0] == 0xFF) {
        throw protocol.ErrResponse(data).toException()
    }
    // EOF 包：0xFE 且长度 < 9
    if (data[0] == 0xFE && data.size < 9) {
        return (Array<Array<Byte>>(0, repeat: Array<Byte>(0, repeat: 0)), false)
    }
    let fields = ArrayList<Array<Byte>>()
    var i = 0
    while (i < data.size) {
        let b = data[i]
        if (b == 0xFB) {
            // NULL
            fields.add(Array<Byte>(0, repeat: 0))
            i++
            continue
        }
        var len: Int64 = 0
        var hdr: Int64 = 0
        if (b < 0xFB) {
            len = Int64(b)
            hdr = 1
        } else if (b == 0xFC) {
            len = Int64(data[i + 1]) | (Int64(data[i + 2]) << 8)
            hdr = 3
        } else if (b == 0xFD) {
            len = Int64(data[i + 1]) | (Int64(data[i + 2]) << 8) | (Int64(data[i + 3]) << 16)
            hdr = 4
        } else if (b == 0xFE) {
            len = Int64(data[i + 1]) | (Int64(data[i + 2]) << 8) | (Int64(data[i + 3]) << 16) |
                (Int64(data[i + 4]) << 24) | (Int64(data[i + 5]) << 32) | (Int64(data[i + 6]) << 40) |
                (Int64(data[i + 7]) << 48) | (Int64(data[i + 8]) << 56)
            hdr = 9
        } else {
            throw sql.SqlException("文本协议行解析失败: 未知长度前缀 ${b}")
        }
        let start = i + hdr
        let end = start + len
        if (end > data.size) {
            throw sql.SqlException("文本协议行解析失败: 字段越界")
        }
        fields.add(data[start..end])
        i = end
    }
    return (fields.toArray(), true)
}
