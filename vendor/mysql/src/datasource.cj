package mysql

import mysql.data
import mysql.driver

/**
 * 数据源接口
 */
public class Datasource <: driver.Datasource {
    public init(config: data.Config) {
        super(config)
    }
    
    public func connect(): Connection {
        return Connection(this.pool)
    }
}