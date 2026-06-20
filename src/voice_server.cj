// voice_server.cj — 纯 Cangjie 语音服务（全 TCP）
// TCP 6808: 认证 + 信令 + 语音转发
// 协议: 连接→发呼号\n → SERVER:呼号\n
//       信令: {"type":"channel","data":"122800:1"}\n
//       语音帧: len(4小端) + freq(4小端) + opus_data

package FSD_Cangjie

import std.net.*
import std.collection.*

public class VoiceServer {
    var running: Bool
    var clients: ArrayList<VoiceClient>
    var serverSocket: ?TcpServerSocket

    public init() {
        this.running = false
        this.clients = ArrayList<VoiceClient>()
        this.serverSocket = None
    }

    public func start(port: Int32): Unit {
        this.running = true
        // 主线程绑定，避免 spawn 延迟
        try {
            var ss = TcpServerSocket(bindAt: UInt16(port))
            ss.bind()
            this.serverSocket = Some(ss)
            dolog(L_INFO, "Voice server on TCP ${port}")
            spawn { acceptLoop() }
        } catch (e: Exception) {
            dolog(L_WARNING, "Voice TCP bind: ${e}")
        }
    }

    public func stop(): Unit {
        this.running = false
        match (this.serverSocket) { case Some(ss) => try { ss.close() } catch (_: Exception) {}; case None => () }
    }

    private func acceptLoop(): Unit {
        match (this.serverSocket) {
            case Some(ss) =>
                while (this.running) {
                    try { let s = ss.accept(); spawn { handleClient(s) } }
                    catch (_: Exception) { if (!this.running) { break } }
                }
                ss.close()
            case None => ()
        }
    }

    private func handleClient(socket: TcpSocket): Unit {
        var buf = Array<UInt8>(8192, repeat: 0u8)
        var lineBytes = ArrayList<UInt8>()
        var callsign = ""
        var voiceBuf = ArrayList<UInt8>()

        try {
            // === 阶段 1：握手 — 只读呼号行，写 SERVER: 响应 ===
            var gotLine = false
            while (!gotLine && this.running) {
                let n = socket.read(buf)
                if (n <= 0) { socket.close(); return }
                for (i in 0..n) {
                    if (buf[i] == UInt8(10) && !gotLine) {
                        if (lineBytes.size > 0) {
                            callsign = String.fromUtf8(lineBytes.toArray()).trim()
                            lineBytes.clear()
                            gotLine = true
                        }
                        break
                    }
                    if (!gotLine) { lineBytes.add(buf[i]) }
                }
            }
            if (callsign == "") { try { socket.close() } catch (_: Exception) {}; return }

            // 写 SERVER: 响应（写操作在 read 循环之外，避免 Cangjie TcpSocket 读写冲突）
            this.clients.add(VoiceClient(callsign, "0", socket))
            dolog(L_INFO, "Voice + ${callsign}")
            socket.write(("SERVER:${callsign}\n").toArray())
            dolog(L_INFO, "Voice response sent to ${callsign}")

            // === 阶段 2：主循环 — 语音帧 + 信令 ===
            while (this.running) {
                let n = socket.read(buf)
                if (n <= 0) { break }
                for (i in 0..n) {
                    let b = buf[i]
                    if (b == UInt8(10)) {  // \n = 文本行（信令）
                        if (lineBytes.size > 0) {
                            let raw = String.fromUtf8(lineBytes.toArray()).trim()
                            lineBytes.clear()
                            if (raw != "") { parseSignal(raw, callsign, socket) }
                        }
                        continue
                    }
                    // 二进制语音帧数据
                    voiceBuf.add(b)
                    while (voiceBuf.size >= 8) {
                        let frameLen = bytesToInt64(voiceBuf, 0)
                        let totalLen: Int64 = 8 + frameLen
                        if (voiceBuf.size < totalLen) { break }
                        let freq = bytesToInt64(voiceBuf, 4)
                        // 转发完整帧(含帧头)给同频率客户端
                        var frameData = ArrayList<UInt8>()
                        for (j in 0..totalLen) { frameData.add(voiceBuf[j]) }
                        let out = frameData.toArray()
                        for (j in 0..this.clients.size) {
                            let c = this.clients[Int64(j)]
                            if (c.callsign == callsign) { continue }
                            if (parseInt64(c.frequency) == freq) {
                                try { c.socket.write(out) } catch (_: Exception) {}
                            }
                        }
                        // 移除已处理帧
                        var rem = ArrayList<UInt8>()
                        for (j in totalLen..voiceBuf.size) { rem.add(voiceBuf[j]) }
                        voiceBuf = rem
                    }
                }
            }
        } catch (_: Exception) {}
        if (callsign != "") { removeClient(callsign) }
        try { socket.close() } catch (_: Exception) {}
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

    private func parseSignal(raw: String, callsign: String, socket: TcpSocket): Unit {
        let msgType = jsonExtract(raw, "type")
        let msgData = jsonExtract(raw, "data")
        if (msgType == "ping") {
            socket.write("{\"type\":\"pong\"}\n".toArray())
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
        let search = "\"${key}\":\""
        let rs = raw.toRuneArray(); let sr = search.toRuneArray()
        if (sr.size > rs.size) { return "" }
        for (i in 0..(rs.size - sr.size)) {
            var ok = true
            for (j in 0..sr.size) { if (rs[i + j] != sr[j]) { ok = false; break } }
            if (ok) {
                var r = ""
                for (k in (i + Int64(sr.size))..rs.size) {
                    if (rs[k] == r'\"') { break }
                    r += charStr(rs[k])
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
    var socket: TcpSocket
    public init(cs: String, freq: String, s: TcpSocket) {
        this.callsign = cs; this.frequency = freq; this.socket = s
    }
}
