// voice_server.cj — 语音服务（TcpStreamX 封装）
package FSD_Cangjie

import std.net.*
import std.collection.*

public class VoiceServer {
    var running: Bool
    var clients: ArrayList<VoiceClient>
    var listener: ?TcpListenerX

    public init() {
        this.running = false
        this.clients = ArrayList<VoiceClient>()
        this.listener = None
    }

    public func start(port: Int32): Unit {
        this.running = true
        try {
            let srv = TcpListenerX(UInt16(port))
            srv.bind()
            this.listener = Some(srv)
            dolog(L_INFO, "Voice server on TCP ${port}")
            spawn { acceptLoop() }
        } catch (e: Exception) {
            dolog(L_WARNING, "Voice TCP bind: ${e}")
        }
    }

    public func stop(): Unit {
        this.running = false
        match (this.listener) { case Some(srv) => try { srv.close() } catch (_: Exception) {}; case None => () }
    }

    private func acceptLoop(): Unit {
        match (this.listener) {
            case Some(srv) =>
                while (this.running) {
                    try { let s = srv.accept(); spawn { handleClient(s) } }
                    catch (_: Exception) { if (!this.running) { break } }
                }
                srv.close()
            case None => ()
        }
    }

    private func handleClient(stream: TcpStreamX): Unit {
        var buf = Array<UInt8>(8192, repeat: 0u8)
        var lineBuf = ArrayList<UInt8>()
        var callsign = ""
        var voiceBuf = ArrayList<UInt8>()

        try {
            while (this.running) {
                let n = stream.read(buf)
                if (n <= 0) { break }
                for (i in 0..n) {
                    let b = buf[i]
                    if (b == UInt8(10)) {
                        if (lineBuf.size > 0) {
                            let raw = String.fromUtf8(lineBuf.toArray()).trim()
                            lineBuf.clear()
                            if (raw == "") { continue }
                            if (callsign == "") {
                                callsign = raw
                                this.clients.add(VoiceClient(callsign, "0", stream))
                                dolog(L_INFO, "Voice + ${callsign}")
                                let resp = ("SERVER:${callsign}\n").toArray()
                                stream.write(resp)
                            } else {
                                parseSignal(raw, callsign, stream)
                            }
                        }
                        continue
                    }
                    if (callsign != "") {
                        voiceBuf.add(b)
                        while (voiceBuf.size >= 8) {
                            let frameLen = bytesToInt64(voiceBuf, 0)
                            if (frameLen < 1 || frameLen > 65536) { voiceBuf.clear(); break }  // 帧长度异常，清空
                            let totalLen: Int64 = 8 + frameLen
                            if (voiceBuf.size < totalLen) { break }
                            let freq = bytesToInt64(voiceBuf, 4)
                            for (j in 0..this.clients.size) {
                                let c = this.clients[Int64(j)]
                                if (c.callsign == callsign) { continue }
                                if (parseInt64(c.frequency) == freq) {
                                    var frameData = ArrayList<UInt8>()
                                    for (k in 0..totalLen) { frameData.add(voiceBuf[k]) }
                                    try { c.stream.write(frameData.toArray()) } catch (_: Exception) {}
                                }
                            }
                            var rem = ArrayList<UInt8>()
                            for (j in totalLen..voiceBuf.size) { rem.add(voiceBuf[j]) }
                            voiceBuf = rem
                        }
                    }
                }
            }
        } catch (_: Exception) {}
        if (callsign != "") { removeClient(callsign) }
        try { stream.close() } catch (_: Exception) {}
    }

    private func removeClient(callsign: String): Unit {
        for (i in 0..this.clients.size) {
            if (this.clients[Int64(i)].callsign == callsign) {
                this.clients.remove(Int64(i)..(Int64(i) + 1))
                dolog(L_INFO, "Voice - ${callsign}")
                break
            }
        }
    }

    private func parseSignal(raw: String, callsign: String, stream: TcpStreamX): Unit {
        let msgType = jsonExtract(raw, "type")
        let msgData = jsonExtract(raw, "data")
        if (msgType == "ping") {
            stream.write("{\"type\":\"pong\"}\n".toArray())
        } else if (msgType == "channel") {
            let ch = splitStr(msgData, ":")
            if (ch.size >= 1) {
                for (i in 0..this.clients.size) {
                    if (this.clients[Int64(i)].callsign == callsign) {
                        this.clients[Int64(i)].frequency = ch[0]
                        break
                    }
                }
            }
        }
    }

    private func jsonExtract(raw: String, key: String): String {
        let search = "\"${key}\":"
        let rs = raw.toRuneArray(); let sr = search.toRuneArray()
        if (sr.size > rs.size) { return "" }
        for (i in 0..(rs.size - sr.size)) {
            var ok = true
            for (j in 0..sr.size) { if (rs[i + j] != sr[j]) { ok = false; break } }
            if (ok) {
                // 跳过空格
                var pos = i + Int64(sr.size)
                while (pos < rs.size && rs[pos] == r' ') { pos += 1 }
                // 必须跟引号
                if (pos >= rs.size || rs[pos] != r'\"') { return "" }
                pos += 1
                // 提取值直到遇到未转义的引号
                var r = ""
                while (pos < rs.size) {
                    if (rs[pos] == r'\\') {  // 转义序列
                        pos += 1
                        if (pos < rs.size) { r += charStr(rs[pos]); pos += 1 }
                    } else if (rs[pos] == r'\"') { break }
                    else { r += charStr(rs[pos]); pos += 1 }
                    if (r.toRuneArray().size > 512) { return "" }  // 防止超长值
                }
                return r
            }
        }
        return ""
    }
    private func charStr(ch: Rune): String {
        if (ch == r'0') { return "0" } else if (ch == r'1') { return "1" } else if (ch == r'2') { return "2" }
        else if (ch == r'3') { return "3" } else if (ch == r'4') { return "4" } else if (ch == r'5') { return "5" }
        else if (ch == r'6') { return "6" } else if (ch == r'7') { return "7" } else if (ch == r'8') { return "8" }
        else if (ch == r'9') { return "9" }
        else if (ch == r'a') { return "a" } else if (ch == r'b') { return "b" } else if (ch == r'c') { return "c" }
        else if (ch == r'd') { return "d" } else if (ch == r'e') { return "e" } else if (ch == r'f') { return "f" }
        else if (ch == r'g') { return "g" } else if (ch == r'h') { return "h" } else if (ch == r'i') { return "i" }
        else if (ch == r'j') { return "j" } else if (ch == r'k') { return "k" } else if (ch == r'l') { return "l" }
        else if (ch == r'm') { return "m" } else if (ch == r'n') { return "n" } else if (ch == r'o') { return "o" }
        else if (ch == r'p') { return "p" } else if (ch == r'q') { return "q" } else if (ch == r'r') { return "r" }
        else if (ch == r's') { return "s" } else if (ch == r't') { return "t" } else if (ch == r'u') { return "u" }
        else if (ch == r'v') { return "v" } else if (ch == r'w') { return "w" } else if (ch == r'x') { return "x" }
        else if (ch == r'y') { return "y" } else if (ch == r'z') { return "z" }
        return "?"
    }
    private func bytesToInt64(b: ArrayList<UInt8>, off: Int64): Int64 {
        var r: Int64 = 0
        for (i in 0..4) { r = r | (Int64(b[off + i]) << (i * 8)) }
        return r
    }
}

public class VoiceClient {
    var callsign: String
    var frequency: String
    var stream: TcpStreamX
    public init(cs: String, freq: String, s: TcpStreamX) {
        this.callsign = cs; this.frequency = freq; this.stream = s
    }
}
