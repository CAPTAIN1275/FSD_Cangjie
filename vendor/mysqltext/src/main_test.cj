package mysql

import mysql.driver
import std.database.sql
import std.time

// CREATE TABLE `users` (
//   `id` int unsigned NOT NULL AUTO_INCREMENT,
//   `age` int DEFAULT NULL,
//   `name` varchar(255) DEFAULT NULL,
//   `coin` double DEFAULT NULL,
//   `create_at` datetime DEFAULT NULL,
//   PRIMARY KEY (`id`) USING BTREE
// ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

var conn: ?Connection = None

private func getDB() {
    match (conn) {
        case None => 
            let datasource = Driver("base-mysql").open(
            "root:root@tcp(127.0.0.1:3306)/temp",
            [("poolMaxCount", "1")]
        )
        conn = datasource.connect()
        case Some(conn) => return conn
    }
    
    return conn.getOrThrow()
}

// 标准库测试
@Test
func baseCURDTest() {
    let datasource = driver.Driver("base-mysql").open(
        "root:root@tcp(127.0.0.1:3306)/temp",
        [("poolMaxCount", "1")]
    )
    let conn = datasource.connect()
    let stmt1 = conn.prepareStatement("INSERT INTO users VALUES(NULL, ? , ?, '1.9', ?)")
    stmt1.set(0, 1)
    stmt1.set(1, "abcd")
    stmt1.setNull(2)
    var upRet = stmt1.update()
    @Expect(upRet.lastInsertId > 0, true)
    stmt1.close()

    let checkID = upRet.lastInsertId

    let stmt2 = conn.prepareStatement("SELECT * FROM users WHERE id = ? LIMIT 1")
    stmt2.set(0, checkID)
    let queryRet = stmt2.query()
    while (queryRet.next()) {
        let name = queryRet.get<String>(2)
        @Expect(name, "abcd")
    }
    stmt2.close()
    
    let stmt3 = conn.prepareStatement("UPDATE users SET name = ? WHERE id = ?")
    stmt3.set(0, "abcd changed")
    stmt3.set(1, checkID)
    upRet = stmt3.update()
    @Expect(upRet.rowCount > 0, true)
    stmt3.close()
    
    let stmt4 = conn.prepareStatement("DELETE FROM users WHERE id = ? AND name = ?")
    stmt4.set(0, checkID)
    stmt4.set(1, "abcd changed")
    upRet = stmt4.update()
    @Expect(upRet.rowCount > 0, true)
    stmt4.close()
}


// 其他扩展函数测试
@Test
func plusQueryTest() {
    let conn = getDB()
    // 使用扩展函数直接更新, 没有传参的值自动填充为null
    let upRet = conn.update("INSERT INTO users VALUES(NULL, ? , ?, '1.9', ?)", 1, "update++")

    @Expect(upRet.lastInsertId > 0, true)

    let queryRet = conn.query("SELECT * FROM users WHERE id = ? LIMIT 1", upRet.lastInsertId)
    for (ret in queryRet) {
        let name = ret.getString("name")
        @Expect(name, "update++")

        let coin = ret.getFloat64("coin")
        @Expect(coin, 1.9)
    }
}