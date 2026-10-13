package mysql

import mysql.data
import mysql.driver

/**
 * 数据库驱动接口
*/
public class Driver <: driver.Driver {
    public init() {
        super()
    }

    public init(scheme: String) {
        super(scheme)
    }
    /*
     * 通过connectionString和选项打开数据源
     *
     * 参数 connectionString - 数据库连接字符串
     * 参数 opt - key,value的tuple数组，打开数据源的选项
     * 返回值 Datasource - 数据源实例
     * 异常 SqlException - connectionString连接内容不正确会导致异常
     */
    public override func open(connStr: String, opt: Array<(String, String)>): Datasource {
        return Datasource(data.Config(connStr, opt))
    }
}