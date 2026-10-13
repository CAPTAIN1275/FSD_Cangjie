package mysql.driver

import std.database.sql
import mysql.data

/**
 * 数据源接口
 */
public open class Datasource <: sql.Datasource {
    protected let pool: data.Pool
    protected let config: data.Config
    public init(config: data.Config) {
        if (config.poolMaxCount == Int64(1)) {
            // connect出来是一个阻塞的链接, 以后全局共用
            this.pool = data.OneClient(config)
        } else {
            // connect出来是一个管道设计, 每个 sql 操作都可能是不同的链接, 对应链接在操作完成后自动返回连接池中
            this.pool = data.MultipleClient(config)
        }
        
        this.config = config
    }

    public open func connect(): Connection {
        return Connection(this.pool)
    }

    public func setOption(key: String, value: String): Unit {
        this.config.setOption(key, value)
    }

    public func isClosed(): Bool {
        false
    }
    public func close(): Unit {
        this.pool.close()
    }
}
