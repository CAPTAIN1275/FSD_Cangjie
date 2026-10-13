package mysql.driver

import std.database.sql
import mysql.data

/**
 * 数据库驱动接口
*/
public open class Driver <: sql.Driver {
    public init() {
        sql.DriverManager.register("mysql", Driver("mysql"))
    }
    
    private var scheme = "mysql"
    public init(scheme: String) {
        this.scheme = scheme.toAsciiLower()
    }
    
    public prop name: String {
        get() {
            return this.scheme
        }
    }

    /**
     * 驱动版本
     *
     * 异常 SqlException - 获取版本失败
     */
    public override prop version: String {
        get() {
            return "0.1.0"
        }
    }

    /**
     * 指示驱动程序是否与连接池亲和。
     * 如果否，则不建议使用连接池。
     * 比如sqlite驱动连接池化的收益不明显，不建议使用连接池
     */
    public override prop preferredPooling: Bool {
        get() {
            return true
        }
    }

    /*
     * 通过connectionString和选项打开数据源
     *
     * 参数 connectionString - 数据库连接字符串
     * 参数 opt - key,value的tuple数组，打开数据源的选项
     * 返回值 Datasource - 数据源实例
     * 异常 SqlException - connectionString连接内容不正确会导致异常
     */
    public open func open(connStr: String, opt: Array<(String, String)>): Datasource {
        return Datasource(data.Config(connStr, opt))
    }
}