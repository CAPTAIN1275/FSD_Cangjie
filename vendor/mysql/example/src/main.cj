package example

import std.database.sql
import std.time.*
import mysql.*
import jlog as log

main(): Int64 {
    let conn = getDB()
    let stmt2 = conn.prepareStatement("SELECT * FROM users")
    let queryRet = stmt2.query()
    while (queryRet.next()) {
        let name = queryRet.get<String>(2)
        log.info("name: ${name}")
    }
    stmt2.close()
    return 0
}

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