package mysql.driver

import std.database.sql
import mysql.data
import mysql.net
import mysql.protocol

/**
 * sql 语句预执行接口
*/
public open class Statement <: sql.Statement {
    protected let client: data.Client

    // stmt id
    protected var prepare = protocol.StmtPrepareResposne()

    protected var params: Array<protocol.SqlData> = []

    public init(client: data.Client, sql: String){
        this.client = client
        this.client.command(protocol.CommandType.StmtPrepare, sql)

        this.client.response(this.prepare)
        if(this.prepare.num_params > 0) {
            this.client.readUntilEOF()
        }
        if(this.prepare.num_columns > 0) {
            this.client.readUntilEOF()
        }
        this.params = Array<protocol.SqlData>(Int64(prepare.num_params), repeat: protocol.SqlNull())
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
        match (value) {
            case v: protocol.SqlData => this.params[index] = v
            case v: ToString => this.params[index] = v.toString()
            case _=> throw sql.SqlException("不支持的参数类型, 你应该实现 protocol.SqlData 接口")
        }
        
    }
	public func setNull(index: Int): Unit {
        this.params[index] = protocol.SqlNull()
    }
    
	public func update(): UpdateResult {
        if (params.size != Int64(prepare.num_params)) {
            throw sql.SqlException("参数数量不匹配; 需要数数量(${prepare.num_params}), 传入参数数量(${params.size}); 也或者预执行语句失败了")
        }

        try {
            this.client.writeExecutePacket(protocol.StmtExecute(params, this.prepare.statement_id))
            let ok = this.client.okResponse()
            return UpdateResult(ok.affected_rows, ok.last_insert_id)
        } catch (e: Exception) {
            // 出错也必须归还连接，否则连接池会被耗尽
            try { this.close() } catch (_: Exception) {}
            throw e
        }
    }
    
	public func query(): QueryResult {
        if (params.size != Int64(prepare.num_params)) {
            throw sql.SqlException("参数数量不匹配; 需要数数量(${prepare.num_params}), 传入参数数量(${params.size}); 也或者预执行语句失败了")
        }

        try {
            this.client.writeExecutePacket(protocol.StmtExecute(params, this.prepare.statement_id))
            return QueryResult(this.client)
        } catch (e: Exception) {
            try { this.close() } catch (_: Exception) {}
            throw e
        }
    }

    public func isClosed(): Bool {
        return this.prepare.statement_id == 0
    }

    public func close(): Unit {
        if (this.isClosed()) {
            return
        }

        let sid = this.prepare.statement_id
        this.prepare.statement_id = 0
        try {
            this.client.command(protocol.CommandType.StmtClose, sid)
        } catch (_: Exception) {
            // 即使 StmtClose 失败也必须归还连接，否则连接池会被耗尽
        }
        this.client.release()
    }
}