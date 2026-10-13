package mysql.driver

import std.database.sql
import mysql.data
import mysql.net
import mysql.protocol

/**
 * 文本协议语句：参数在客户端绑定，走 COM_QUERY。
 * 不再使用服务端预编译语句，规避 statement_id 溢出 / StmtClose / 参数包等问题。
 */
public open class Statement <: sql.Statement {
    protected let client: data.Client
    protected let sqlText: String
    protected let numParams: Int64
    protected var params: Array<?String>
    protected var done: Bool = false

    public init(client: data.Client, sql: String) {
        this.client = client
        this.sqlText = sql
        this.numParams = countPlaceholders(sql)
        this.params = Array<?String>(this.numParams, repeat: None)
    }

    public prop parameterColumnInfos: Array<sql.ColumnInfo> {
        get() {
            return []
        }
    }

    @Deprecated
    public open func query(params: Array<sql.SqlDbType>): QueryResult {
        throw sql.SqlException("已经不支持的接口")
    }

    public func setOption(_: String, _: String): Unit {
    }

    @Deprecated
    public func update(params: Array<sql.SqlDbType>): UpdateResult {
        throw sql.SqlException("已经不支持的接口")
    }

	public func set<T>(index: Int, value: T): Unit {
        if (index < 0 || Int64(index) >= this.numParams) {
            throw sql.SqlException("参数下标越界: ${index} (共 ${this.numParams} 个占位符)")
        }
        this.params[index] = match (value) {
            case _: protocol.SqlNull => None
            case v: ToString => Some(v.toString())
            case _ => throw sql.SqlException("不支持的参数类型, 需要能转换为字符串的类型")
        }
    }

	public func setNull(index: Int): Unit {
        if (index >= 0 && Int64(index) < this.numParams) {
            this.params[index] = None
        }
    }

	public func update(): UpdateResult {
        if (this.done) { throw sql.SqlException("语句已结束") }
        let finalSql = this.bind()
        this.client.command(protocol.CommandType.Query, finalSql)
        try {
            let ok = this.client.okResponse()
            return UpdateResult(ok.affected_rows, ok.last_insert_id)
        } finally {
            this.releaseClient()
        }
    }

	public func query(): QueryResult {
        if (this.done) { throw sql.SqlException("语句已结束") }
        let finalSql = this.bind()
        this.client.command(protocol.CommandType.Query, finalSql)
        // 连接所有权转移给 QueryResult（它在构造时读完并归还），
        // 这里必须先置 done，否则调用方随后 close() 会造成二次归还、池计数错乱
        this.done = true
        return QueryResult(this.client)
    }

    public func isClosed(): Bool {
        return this.done
    }

    public func close(): Unit {
        this.releaseClient()
    }

    // 归还连接（只做一次），保证任何路径都不会泄漏连接池槽位
    private func releaseClient(): Unit {
        if (this.done) { return }
        this.done = true
        try {
            this.client.release()
        } catch (_: Exception) {}
    }

    // 用参数替换 SQL 中的 ? （客户端绑定）
    private func bind(): String {
        let sb = StringBuilder()
        var pi = 0
        for (r in this.sqlText.toRuneArray()) {
            if (r == r'?' && pi < this.numParams) {
                match (this.params[pi]) {
                    case Some(v) => sb.append(escapeSqlLiteral(v))
                    case None => sb.append("NULL")
                }
                pi++
            } else {
                sb.append(r.toString())
            }
        }
        return sb.toString()
    }
}

// 统计 SQL 中 ? 占位符数量
func countPlaceholders(sql: String): Int64 {
    var n = 0
    for (r in sql.toRuneArray()) {
        if (r == r'?') { n++ }
    }
    return n
}

// 按 MySQL 规则转义字符串字面量（含外层单引号）
func escapeSqlLiteral(s: String): String {
    let sb = StringBuilder()
    sb.append("'")
    for (r in s.toRuneArray()) {
        match (r) {
            case r'\'' => sb.append("\\'")
            case r'\\' => sb.append("\\\\")
            case r'\n' => sb.append("\\n")
            case r'\r' => sb.append("\\r")
            case r'\0' => sb.append("\\0")
            case r'\u{1a}' => sb.append("\\Z")
            case _ => sb.append(r.toString())
        }
    }
    sb.append("'")
    return sb.toString()
}
