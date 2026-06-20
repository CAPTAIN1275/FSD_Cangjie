// metar.cj — METAR 天气获取与缓存
// 数据源: https://metar.vatsim.net/ICAO
// 使用 curl 获取（服务器标配），缓存 15 分钟

package FSD_Cangjie

import std.collection.*
import std.process.*

public class MetarManager {
    var source: Int32
    var profiles: HashMap<String, WeatherProfile>
    var lastRefresh: Int64

    public init() {
        this.source = SOURCE_NETWORK
        this.profiles = HashMap<String, WeatherProfile>()
        this.lastRefresh = 0
    }

    public func getMetar(icao: String): ?String {
        match (this.profiles.get(icao)) {
            case Some(p) =>
                // 检查缓存是否过期（15 分钟）
                if (mgmtime() - p.updated < MAXMETARDOWNLOADTIME) {
                    return Some(p.data)
                }
            case None => ()
        }
        return None
    }

    public func setMetar(icao: String, data: String): Unit {
        this.profiles[icao] = WeatherProfile(icao, data, mgmtime())
    }

    public func deleteMetar(icao: String): Unit {
        this.profiles.remove(icao)
    }

    public func run(): Int32 { return 0 }

    // requestMetar — 处理客户端 #WX 请求
    // client: "%callsign" (请求客户端)
    // metar: ICAO 代码 (如 ZGGG)
    // parsed/fd: 保留参数
    public func requestMetar(client: String, metar: String, parsed: Int32, fd: Int32): Unit {
        let icao = metar.toUpper()
        dolog(L_INFO, "METAR request: ${icao} from ${client}")

        // 先查缓存
        match (this.getMetar(icao)) {
            case Some(cached) =>
                dolog(L_INFO, "METAR cache hit: ${icao}")
                sendMetarToClient(client, icao, cached)
                return
            case None => ()
        }

        // 联网获取
        let url = "https://metar.vatsim.net/${icao}"
        dolog(L_INFO, "METAR fetching: ${url}")
        try {
            let (code, stdoutBytes, stderrBytes) = executeWithOutput("curl", [
                "-s", "--connect-timeout", "5",
                "--max-time", "10",
                url
            ])
            if (code == 0) {
                let raw = String.fromUtf8(stdoutBytes).trim()
                if (raw != "" && raw.toRuneArray().size > 3) {
                    dolog(L_INFO, "METAR received: ${raw}")
                    this.setMetar(icao, raw)
                    sendMetarToClient(client, icao, raw)
                    return
                } else {
                    dolog(L_WARNING, "METAR empty response for ${icao}")
                }
            } else {
                let errStr = String.fromUtf8(stderrBytes).trim()
                dolog(L_WARNING, "METAR curl error (${code}): ${errStr}")
            }
        } catch (e: Exception) {
            dolog(L_ERR, "METAR fetch exception: ${e}")
        }

        // 获取失败
        sendMetarToClient(client, icao, "Unable to retrieve METAR for ${icao}")
    }

    // 同步获取 METAR（供管理终端使用，直接返回结果）
    public func fetchMetarSync(icao: String): String {
        let upper = icao.toUpper()
        // 先查缓存
        match (this.getMetar(upper)) {
            case Some(cached) => return cached
            case None => ()
        }
        // 联网获取
        let url = "https://metar.vatsim.net/${upper}"
        try {
            let (code, stdoutBytes, _) = executeWithOutput("curl", [
                "-s", "--connect-timeout", "5",
                "--max-time", "10", url
            ])
            if (code == 0) {
                let raw = String.fromUtf8(stdoutBytes).trim()
                if (raw != "" && raw.toRuneArray().size > 3) {
                    this.setMetar(upper, raw)
                    return raw
                }
            }
        } catch (e: Exception) {}
        return "Unable to retrieve METAR for ${upper}"
    }

    // 发送 METAR 回客户端
    private func sendMetarToClient(client: String, icao: String, data: String): Unit {
        // 解析请求的呼号：client 格式为 "%callsign"
        let callsign = if (client.startsWith("%")) {
            substrFrom(client, 1)
        } else {
            client
        }
        match (clientInterface) {
            case Some(ci) =>
                // 格式：#TMserver:callsign:METAR for ICAO: data
                ci.broadcastToAll("#TMserver:${callsign}:METAR for ${icao}: ${data}\r\n")
            case None => ()
        }
    }
}

public class WeatherProfile {
    var icao: String
    var data: String
    var updated: Int64

    public init(icao: String, data: String, updated: Int64) {
        this.icao = icao
        this.data = data
        this.updated = updated
    }
}
