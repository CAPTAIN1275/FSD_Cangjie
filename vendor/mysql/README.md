### 介绍

仓颉语言原生 `mysql` 驱动, 完全符合官方标准库接口约束。

内部自动维护连接池, 无需手动管理; 除了提供官方 `database.sql` 的实现, 同时也扩展了一些更加便捷的接口。

https://gitcode.com/service/cangjie-mysql-driver/overview

### 安装

引入依赖管理

```toml
[dependencies]
mysql = {git = "https://gitcode.com/service/cangjie-mysql-driver.git", branch = "main", version = "0.0.1"}
```

### 项目结构

```shell
├── example         // 示例代码
│   ├── src
├── src
│   ├── *.cj        // 对官方接口进行扩展能力
│   ├── data        // 驱动内部的对象实例, 例如链接池、具体链接
│   ├── driver      // 官方 database.sql 接口的完整实现, 如果不使用扩展能力, 可以直接使用本目录接口
│   ├── errors      // 自定义错误class
│   ├── net         // 和 mysql server 通讯层封装
│   └── protocol    // 和数据库通讯过程的协议封装
```

### 官方接口使用

测试表结构和代码都能在 [example](example) 找到。<br>
其他使用直接查看官方文档即可, **`mysql.driver` 模块会保持 ==`100%`== 兼容。**

```cj
package example

import std.database.sql.*
import mysql.driver

main(): Int64 {
    // poolMaxCount=1, 是一个特殊的处理, 是完全由官方接口约束的实现; datasource.connect() 后, 只有一个链接
    // poolMaxCount 其他值时, 每种子会话都自动申请链接并放回去; datasource.connect() 后, 是一个链接池
    let datasource = driver.Driver().open(
        "root:root@tcp(127.0.0.1:3306)/temp",
        [("poolMaxCount", "1")]
    )
    let conn = datasource.connect()
    let stmt1 = conn.prepareStatement("INSERT INTO users VALUES(NULL, ? , ?, '1.9', NULL)")
    let upRet = stmt1.update(SqlInteger(0), SqlNullableVarchar("abcd"))
    println("lastInsertId = ${upRet.lastInsertId}")
    stmt1.close()
}

```

### 高级功能

官方的 `database.sql` 接口定义, 并不能在真实业务中完全满足需求。每个操作过于细化和繁琐, 因此本驱动提供了一些更加便捷的接口。<br>
扩展功能都继承`mysql.driver`模块, 也能使用官方 `database.sql` 接口。

```cj
package example

import std.database.sql.*
import std.time.*
import mysql
import jlog as log

func curd() {
    let db = db()
    let upRet = db.update("INSERT INTO users VALUES(NULL, ? , ?, '1.9', ?)", 0, "init", now())
    log.info("插入数据 lastInsertId = ${upRet.lastInsertId}")

    if (!isFind(upRet.lastInsertId)) {
        log.error("读取数据失败 ${upRet.lastInsertId}")
        return
    }

    db.update("UPDATE `users` SET `name` = 'upName' WHERE `id` = ?", upRet.lastInsertId)
    let upRow = find(upRet.lastInsertId)
    if (let Some(row) <- upRow) {
        if (row.getString("name").getOrThrow() != "upName") {
            log.info("修改数据失败")
            return
        }
    }

    db.update("DELETE FROM `temp`.`users` WHERE `id` = ?", upRet.lastInsertId)
    if (isFind(upRet.lastInsertId)) {
        log.error("删除失败 ${upRet.lastInsertId}")
        return
    }
}

func find(id: Int64): ?mysql.SqlRowData {
    let queryRet = db().query("SELECT * FROM users WHERE id=? LIMIT 1", id)
    if (queryRet.size != 1) {
        return None
    }
    return queryRet[0]
}

func isFind(id: Int64) {
    if (let Some(row) <- find()) {
        if (row.getInt("id").getOrThrow() != id) {
            return false
        }
    }
    return true
}

var conn: ?mysql.Connection = None

func db(): mysql.Connection {
    match (conn) {
        case None =>
            log.SetLevel(log.LogLevel.trace)
            // 初始化数据库驱动, 默认连接池大小为 0-1000
            conn = mysql.Driver().open("root:root@tcp(127.0.0.1:3306)/temp").connect()
        case _ => conn.getOrThrow()
    }
    return conn.getOrThrow()
}

```

##### 事务操作

```cj
func testTransaction() {
    let db = db()
    db.update("DELETE FROM `users` WHERE `id` = ?", 9999)
    // 闭包方式事务, 更加安全
    db.transaction({tx =>
        let upRet = tx.update("INSERT INTO users VALUES(9999, ? , ?, '1.9', ?)", 0, "init", now())
        tx.update("UPDATE `users` SET `name` = 'upName 1' WHERE `id` = ?", upRet.lastInsertId)
        log.info("事务内, 准备插入 id = ${upRet.lastInsertId}; 模拟回滚")

        return false
    })

    if (!isFind(9999)) {
        log.error("回滚成功")
    }
    // 自定义控制提交和回滚
    let tx = db.createTransaction()
    tx.begin()
    let upRet = tx.update("INSERT INTO users VALUES(9999, ? , ?, '1.9', ?)", 0, "init", now())
    tx.update("UPDATE `users` SET `name` = 'upName 1' WHERE `id` = ?", upRet.lastInsertId)
    tx.commit()

    if (isFind(9999)) {
        log.error("提交成功")
    }
}

```

##### 模型操作

模型操作不在当前项目提供, 请查看 [jorm](https://gitcode.com/service/jorm/overview) 仓库。

```cj
let users1 = UsersModel().whereId(1).whereName("age > 1").first()
let users2 = UsersModel()
        .select("users.id, users.name")
        .whered("name = ? and age > ?" , "service", 19)
        .join("left join users_info on users.id = users_info.user_id")
        .get()
```

### 连接参数

| 选项名       | 默认值 | 说明                                              |
| ------------ | ------ | ------------------------------------------------- |
| poolMinSize  | 0      | 连接池初始化的数量, 0 值不做初始化,使用时再初始化 |
| poolMaxCount | 1000   | 连接池链接数量允许的最大值                        |

#### 常见问题

- `Mac OS` 下无法自动识别 `openssl`, 那是 `cangjie` 自身问题, 直接复制 `openssl` 到 `/usr/local/bin` 即可。

#### 感谢

- `mysqlclient-ffi` 项目初始时参考了该项目的文件命名, 和 mysql data type 映射 cangjie SqlDbType 函数。
- `go-sql-driver/mysql` 项目初始也参考了该项目的处理流程, 如协议解析、加密方式, 还有连接池管理思想等的实现方式。

<br>

虽然项目有参考以上代码, 但不准备兼容和继承它们。
