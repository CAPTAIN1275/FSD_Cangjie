// httpapi.cj — HTTP REST API 服务端
// 端点:
//   GET  /api/status           — 服务器状态 JSON
//   POST /api/flightplan       — 提交飞行计划 (query: callsign&cid&fp_data)
//   GET  /api/flightplan       — 查询飞行计划 (query: callsign)
//   DELETE /api/flightplan     — 删除飞行计划 (query: callsign)

package FSD_Cangjie

import std.net.*
import std.collection.*

public class HttpApi {
    var port: Int32
    var apiKey: String
    var running: Bool
    var server: ?TcpServerSocket

    public init(port: Int32, apiKey: String) {
        this.port = port
        this.apiKey = apiKey
        this.running = false
        this.server = None
    }

    public func start(): Unit {
        this.running = true
        spawn { acceptLoop() }
    }

    public func stop(): Unit {
        this.running = false
    }

    private func acceptLoop(): Unit {
        try {
            var ss = TcpServerSocket(bindAt: UInt16(this.port))
            this.server = ss
            ss.bind()
            dolog(L_INFO, "HTTP API listening on port ${this.port}")
            while (this.running) {
                try {
                    let s = ss.accept()
                    spawn { handleConnection(s) }
                } catch (e: Exception) {
                    if (this.running) {
                        dolog(L_WARNING, "HTTP API accept error: ${e}")
                    }
                }
            }
            ss.close()
        } catch (e: Exception) {
            dolog(L_ERR, "HTTP API BIND FAIL on port ${this.port}: ${e}")
        }
    }

    private func handleConnection(socket: TcpSocket): Unit {
        var buf = Array<UInt8>(4096, repeat: 0u8)
        try {
            let n = socket.read(buf)
            if (n <= 0) { socket.close(); return }

            // 解析 HTTP 请求行
            let raw = String.fromUtf8(buf[0..n])
            let lines = splitStr(raw, "\r\n")
            if (lines.size < 1) { socket.close(); return }

            let requestLine = splitStr(lines[0], " ")
            if (requestLine.size < 3) { socket.close(); return }

            let method = requestLine[0]
            let fullPath = requestLine[1]
            // 分离 path 和 query
            var path = fullPath
            var query = ""
            match (fullPath.indexOf(r'?')) {
                case Some(pos) =>
                    path = substrTo(fullPath, pos)
                    query = substrFrom(fullPath, pos + 1)
                case None => ()
            }

            // 获取客户端 IP（空字符串，因为 Cangjie 无法获取）
            let remoteIp = "unknown"

            let (statusCode, contentType, body) = handleRequest(method, path, query, remoteIp)
            let response = "HTTP/1.1 ${statusCode} ${statusText(statusCode)}\r\n" +
                "Content-Type: ${contentType}\r\n" +
                "Access-Control-Allow-Origin: *\r\n" +
                "Access-Control-Allow-Methods: GET, POST, DELETE, OPTIONS\r\n" +
                "Access-Control-Allow-Headers: Content-Type\r\n" +
                "Content-Length: ${Int64(body.toRuneArray().size)}\r\n" +
                "Connection: close\r\n\r\n" +
                body
            socket.write(response.toArray())
        } catch (_: Exception) {}
        try { socket.close() } catch (_: Exception) {}
    }

    private func handleRequest(method: String, path: String, query: String, remoteIp: String): (Int32, String, String) {
        // API 密钥验证
        let params = splitStr(query, "&")
        var providedKey = ""
        for (i in 0..params.size) {
            let pair = splitStr(params[Int64(i)], "=")
            if (pair.size == 2 && pair[0] == "key") { providedKey = pair[1] }
        }
        if (this.apiKey != "" && providedKey != this.apiKey) {
            return (403, "application/json", '{"status":"error","message":"Forbidden"}')
        }

        // CORS preflight
        if (method == "OPTIONS") {
            return (200, "text/plain", "OK")
        }

        if (path == "/api/status" || path == "/api/v1/status") {
            if (method == "GET") {
                return (200, "application/json", handleGetStatus())
            }
            return (405, "text/plain", "Method not allowed")
        }

        if (path == "/api/flightplan" || path == "/api/v1/flightplan") {
            if (method == "POST") {
                let (code, body) = handleSubmitFlightPlan(query)
                return (code, "application/json", body)
            }
            if (method == "GET") {
                // 解析 callsign 参数
                var callsign = ""
                for (param in splitStr(query, "&")) {
                    let pair = splitStr(param, "=")
                    if (pair.size == 2 && pair[0] == "callsign") {
                        callsign = pair[1]
                    }
                }
                if (callsign == "") {
                    return (400, "application/json", "{\"error\":\"Missing callsign\"}")
                }
                let (code, body) = handleGetFlightPlan(callsign)
                return (code, "application/json", body)
            }
            if (method == "DELETE") {
                var callsign = ""
                for (param in splitStr(query, "&")) {
                    let pair = splitStr(param, "=")
                    if (pair.size == 2 && pair[0] == "callsign") {
                        callsign = pair[1]
                    }
                }
                if (callsign == "") {
                    return (400, "application/json", "{\"error\":\"Missing callsign\"}")
                }
                let (code, body) = handleDeleteFlightPlan(callsign)
                return (code, "application/json", body)
            }
            return (405, "text/plain", "Method not allowed")
        }

        return (404, "application/json", "{\"error\":\"Not found\"}")
    }

    private func statusText(code: Int32): String {
        if (code == 200) { return "OK" }
        if (code == 201) { return "Created" }
        if (code == 400) { return "Bad Request" }
        if (code == 404) { return "Not Found" }
        if (code == 405) { return "Method Not Allowed" }
        if (code == 500) { return "Internal Server Error" }
        return "Unknown"
    }

    public func handleGetStatus(): String {
        var uptime: Int64 = 0
        match (fsdEngine) {
            case Some(e) =>
                // 用当前时间减去启动时间
                uptime = mgmtime() - e.prevNotify
            case None => ()
        }
        return "{\"status\":\"online\",\"version\":\"${VERSION}\"," +
            "\"clients\":${clientCount()},\"servers\":${serverCount()}," +
            "\"uptime\":${uptime}}"
    }

    public func handleSubmitFlightPlan(query: String): (Int32, String) {
        if (query == "") { return (400, "{\"error\":\"Missing parameters\"}") }
        var callsign = ""; var cid = ""; var fpData = ""
        for (param in splitStr(query, "&")) {
            let pair = splitStr(param, "=")
            if (pair.size == 2) {
                if (pair[0] == "callsign") { callsign = pair[1] }
                else if (pair[0] == "cid") { cid = pair[1] }
                else if (pair[0] == "fp_data") { fpData = pair[1] }
            }
        }
        if (callsign == "" || cid == "" || fpData == "") {
            return (400, "{\"error\":\"Missing required fields\"}")
        }
        match (gMysql) {
            case Some(db) =>
                if (db.saveFlightPlan(callsign, cid, fpData)) {
                    return (201, "{\"status\":\"success\"}")
                }
                return (500, "{\"error\":\"Failed\"}")
            case None =>
                return (500, "{\"error\":\"DB unavailable\"}")
        }
    }

    public func handleGetFlightPlan(callsign: String): (Int32, String) {
        match (gMysql) {
            case Some(db) =>
                match (db.getFlightPlan(callsign)) {
                    case Some(fp) =>
                        return (200, "{\"status\":\"success\",\"fp_data\":\"${fp}\"}")
                    case None =>
                        return (404, "{\"error\":\"Not found\"}")
                }
            case None =>
                return (500, "{\"error\":\"DB unavailable\"}")
        }
    }

    public func handleDeleteFlightPlan(callsign: String): (Int32, String) {
        match (gMysql) {
            case Some(db) =>
                if (db.deleteFlightPlan(callsign)) {
                    return (200, "{\"status\":\"success\"}")
                }
                return (500, "{\"error\":\"Failed\"}")
            case None =>
                return (500, "{\"error\":\"DB unavailable\"}")
        }
    }

    public func run(): Int32 { return 0 }
}
