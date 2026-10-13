package mysql.data

import std.convert.*

public class Config {
    // 地址, 只能是IP或域名
    var address: String = "127.0.0.1"
    var port: UInt16 = 3306
    var net: String = "tcp"

    var user: String = "root"
    var password: String = "root"
    var database: String = "test"

    var tls: Bool = false

    // 编码
    let collation: String = "utf8mb4_general_ci"

    // 连接池相关配置
    public var poolMaxCount: Int64 = 1000
    public var poolMinSize: Int64 = 0

    // root:root@localhost:3307/temp
    public init(dsn: String, opt: Array<(String, String)>) {
        this.parseDSN(dsn)
        this.parseOptions(opt)
    }

    public func setOption(key: String, val: String) {
        match (key) {
            case "poolMaxCount" => this.poolMaxCount = Int64.parse(val)
            case "poolMinSize" => this.poolMinSize = Int64.parse(val)

            case _ => ()
        }
    }

    protected func parseOptions(opt: Array<(String, String)>) {
        for ((key, val) in opt) {
            this.setOption(key, val)
        }
    }

    /**
     * 对dsn格式进行解析
     * dsn: root:root@localhost:3307/temp
     */
    protected func parseDSN(dsn: String) {
        for (i in 0..dsn.size) {
            if (Rune(dsn[i]) == r'/') {
                var j: Int64
                // var k: Int64

                if (i > 0) {
                    // [username[:password]@][protocol[(address)]]
                    j = i
                    do {
                        if (Rune(dsn[j]) == r'@') {
                            // username[:password]
                            // Find the first ':' in dsn[:j]
                            var k = 0
                            do {
                                if (Rune(dsn[k]) == r':') {
                                    this.password = dsn[k + 1..j]
                                    break
                                }

                                k++
                            } while (k < j)

                            this.user = dsn[0..k]
                            break
                        }

                        j--
                    } while (j >= 0)

                    // [protocol[(address)]]
                    // Find the first '(' in dsn[j+1:i]
                    var k = j + 1
                    do {
                        if (Rune(dsn[k]) == r'(') {
                            var arr = dsn[k + 1..i - 1].split(":")
                            this.address = arr[0]
                            if (arr.size > 1) {
                                this.port = UInt16.parse(arr[1])
                            }
                            break
                        }

                        k++
                    } while (k < i)

                    this.net = dsn[j + 1..k]
                    if (this.net == "") {
                        this.net = "tcp"
                    }
                }

                // dbname[?param1=value1&...&paramN=valueN]
                // Find the first '?' in dsn[i+1:]
                j = i + 1
                do {
                    if (Rune(dsn[j]) == r'?') {
                        throw Exception("无效 dsn, 当前未支持 dsn 参数")
                    }

                    j++
                } while (j < dsn.size)

                this.database = dsn[i + 1..j]
            }
        }
    }
}
