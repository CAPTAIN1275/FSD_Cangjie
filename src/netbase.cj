package FSD_Cangjie

import std.net.*
import std.collection.*
import std.sync.*

func sendTo(user: NetUser, data: String): Unit {
    let bytes = data.toArray()
    // 仅对 #TM 消息打日志，对比收发字节
    if (data.startsWith("#TM")) {
        var logStr = "SEND #TM (${bytes.size} bytes):"
        for (i in 0..bytes.size) {
            if (i < 12) { logStr += " ${Int64(bytes[i])}" }
        }
        dolog(L_INFO, logStr)
    }
    try { user.socket.write(bytes) } catch (e: Exception) {}
}

func toBuf(s: String): Array<UInt8> { return s.toArray() }

func byteStr(b: UInt8): String {
    if (b == UInt8(32)) { return " " } else if (b == UInt8(33)) { return "!" } else if (b == UInt8(34)) { return "\"" }
    else if (b == UInt8(35)) { return "#" } else if (b == UInt8(36)) { return "$" } else if (b == UInt8(37)) { return "%" }
    else if (b == UInt8(38)) { return "&" } else if (b == UInt8(39)) { return "'" } else if (b == UInt8(40)) { return "(" }
    else if (b == UInt8(41)) { return ")" } else if (b == UInt8(42)) { return "*" } else if (b == UInt8(43)) { return "+" }
    else if (b == UInt8(44)) { return "," } else if (b == UInt8(45)) { return "-" } else if (b == UInt8(46)) { return "." }
    else if (b == UInt8(47)) { return "/" }
    else if (b == UInt8(48)) { return "0" } else if (b == UInt8(49)) { return "1" } else if (b == UInt8(50)) { return "2" }
    else if (b == UInt8(51)) { return "3" } else if (b == UInt8(52)) { return "4" } else if (b == UInt8(53)) { return "5" }
    else if (b == UInt8(54)) { return "6" } else if (b == UInt8(55)) { return "7" } else if (b == UInt8(56)) { return "8" }
    else if (b == UInt8(57)) { return "9" }
    else if (b == UInt8(58)) { return ":" } else if (b == UInt8(59)) { return ";" } else if (b == UInt8(60)) { return "<" }
    else if (b == UInt8(61)) { return "=" } else if (b == UInt8(62)) { return ">" } else if (b == UInt8(63)) { return "?" }
    else if (b == UInt8(64)) { return "@" }
    else if (b == UInt8(65)) { return "A" } else if (b == UInt8(66)) { return "B" } else if (b == UInt8(67)) { return "C" }
    else if (b == UInt8(68)) { return "D" } else if (b == UInt8(69)) { return "E" } else if (b == UInt8(70)) { return "F" }
    else if (b == UInt8(71)) { return "G" } else if (b == UInt8(72)) { return "H" } else if (b == UInt8(73)) { return "I" }
    else if (b == UInt8(74)) { return "J" } else if (b == UInt8(75)) { return "K" } else if (b == UInt8(76)) { return "L" }
    else if (b == UInt8(77)) { return "M" } else if (b == UInt8(78)) { return "N" } else if (b == UInt8(79)) { return "O" }
    else if (b == UInt8(80)) { return "P" } else if (b == UInt8(81)) { return "Q" } else if (b == UInt8(82)) { return "R" }
    else if (b == UInt8(83)) { return "S" } else if (b == UInt8(84)) { return "T" } else if (b == UInt8(85)) { return "U" }
    else if (b == UInt8(86)) { return "V" } else if (b == UInt8(87)) { return "W" } else if (b == UInt8(88)) { return "X" }
    else if (b == UInt8(89)) { return "Y" } else if (b == UInt8(90)) { return "Z" }
    else if (b == UInt8(91)) { return "[" } else if (b == UInt8(92)) { return "\\" } else if (b == UInt8(93)) { return "]" }
    else if (b == UInt8(94)) { return "^" } else if (b == UInt8(95)) { return "_" } else if (b == UInt8(96)) { return "`" }
    else if (b == UInt8(97)) { return "a" } else if (b == UInt8(98)) { return "b" } else if (b == UInt8(99)) { return "c" }
    else if (b == UInt8(100)) { return "d" } else if (b == UInt8(101)) { return "e" } else if (b == UInt8(102)) { return "f" }
    else if (b == UInt8(103)) { return "g" } else if (b == UInt8(104)) { return "h" } else if (b == UInt8(105)) { return "i" }
    else if (b == UInt8(106)) { return "j" } else if (b == UInt8(107)) { return "k" } else if (b == UInt8(108)) { return "l" }
    else if (b == UInt8(109)) { return "m" } else if (b == UInt8(110)) { return "n" } else if (b == UInt8(111)) { return "o" }
    else if (b == UInt8(112)) { return "p" } else if (b == UInt8(113)) { return "q" } else if (b == UInt8(114)) { return "r" }
    else if (b == UInt8(115)) { return "s" } else if (b == UInt8(116)) { return "t" } else if (b == UInt8(117)) { return "u" }
    else if (b == UInt8(118)) { return "v" } else if (b == UInt8(119)) { return "w" } else if (b == UInt8(120)) { return "x" }
    else if (b == UInt8(121)) { return "y" } else if (b == UInt8(122)) { return "z" }
    else if (b == UInt8(123)) { return "{" } else if (b == UInt8(124)) { return "|" } else if (b == UInt8(125)) { return "}" }
    else if (b == UInt8(126)) { return "~" }
    return "?"
}

public open class NetInterface {
    var port: Int32; var name: String; var desc: String; var runFlag: Bool
    var users: ArrayList<NetUser>
    var usersLock = Mutex()
    var floodLimit: Int32; var outBufLimit: Int32
    public init(port: Int32, name: String, description: String) {
        this.port = port; this.name = name; this.desc = description
        this.runFlag = false; this.users = ArrayList<NetUser>()
        this.floodLimit = 100000; this.outBufLimit = 1000000
    }
    public open func createUser(socket: TcpSocket): NetUser { return NetUser(socket) }
    public open func run(): Int32 { return 0 }
    public open func start(): Unit {
        this.runFlag = true
        spawn { acceptLoop() }
    }
    public open func stop(): Unit { this.runFlag = false }
    public func setFlood(_n: Int32): Unit { this.floodLimit = _n }
    public func setOutBufLimit(_n: Int32): Unit { this.outBufLimit = _n }
    // IP 白名单检查钩子（子类重写），默认放行
    public open func checkPeer(_socket: TcpSocket): Bool { return true }

    private func acceptLoop(): Unit {
        try {
            var ss = TcpServerSocket(bindAt: UInt16(this.port))
            ss.bind()
            println("[${this.desc}] port=${this.port}")
            while (this.runFlag) {
                try {
                    if (this.users.size > 1000) {  
                        sleep(100 * Duration.millisecond)
                        continue
                    }
                    let s = ss.accept()
                    if (!this.checkPeer(s)) {
                        dolog(L_INFO, "Connection rejected by allowList")
                        s.close()
                        continue
                    }
                    dolog(L_DEBUG, "New connection on ${this.desc}")
                    spawn { serve(createUser(s)) }
                } catch (e: Exception) {
                    if (this.runFlag) { dolog(L_WARNING, "accept error: ${e}") }
                }
            }
            ss.close()
        } catch (e: Exception) { dolog(L_ERR, "BIND FAIL on port ${this.port}: ${e}") }
    }

    public func serve(u: NetUser): Unit {
        var buf = Array<UInt8>(4096, repeat: 0u8)
        // 先刷新 sendFeed 写入的输出缓冲
        if (u.outStr != "") {
            try { u.socket.write(toBuf(u.outStr)); u.outStr = "" } catch (e: Exception) { return }
        }
        u.onConnect()
        while (this.runFlag) {
            if (u.outStr != "") {
                try { u.socket.write(toBuf(u.outStr)); u.outStr = "" } catch (e: Exception) { break }
            }
            if (u.shouldClose) { break }
            try {
                let n = u.socket.read(buf)
                if (n <= 0) { break }
                // 洪水防护
                let now = mgmtime()
                if (now - u.floodTime > 1) {
                    u.floodBytes = 0; u.floodTime = now
                }
                u.floodBytes += Int64(n)
                if (u.floodBytes > Int64(this.floodLimit) && this.floodLimit > 0) {
                    dolog(L_WARNING, "Flood detected from user, closing")
                    u.shouldClose = true; break
                }
                for (i in 0..n) {
                    let b = buf[i]
                    if (b == UInt8(10)) {
                        if (u.lineBytes.size > 0) {
                            // 去掉末尾 \r
                            let last = u.lineBytes.size - 1
                            if (last >= 0 && u.lineBytes[last] == UInt8(13)) {
                                u.lineBytes.remove(last..last + 1)
                            }
                            // 先尝试 UTF-8 解码
                            try {
                                let line = String.fromUtf8(u.lineBytes.toArray())
                                u.lineBuf = line
                                if (u.lineBuf != "") {
                                    // #TM/#SB 消息：同时走原始字节路径（保持原始编码透传）
                                    let b0 = u.lineBytes[0]; let b1 = u.lineBytes[1]; let b2 = u.lineBytes[2]
                                    if (u.lineBytes.size >= 3 &&
                                        (b0 == UInt8(35) && b1 == UInt8(84) && b2 == UInt8(77)) ||
                                        (b0 == UInt8(35) && b1 == UInt8(83) && b2 == UInt8(66))) {
                                        u.handleRawLine(u.lineBytes)
                                    }
                                    u.handleLine(u.lineBuf)
                                }
                                u.lineBuf = ""
                            } catch (_: Exception) {
                                // 非 UTF-8 编码（如 GBK 中文），走原始字节处理
                                u.handleRawLine(u.lineBytes)
                            }
                        }
                        u.lineBytes.clear()
                    } else if (b != UInt8(13)) {
                        if (u.lineBytes.size > 4096) { u.lineBytes.clear(); break }
                        u.lineBytes.add(b)
                    }
                }
            } catch (e: Exception) {
                dolog(L_ERR, "[BYTES] serve loop: ${e}")
                break
            }
        }
        u.onDisconnect()
    }
}

public open class NetUser {
    var socket: TcpSocket; var alive: Int64; var outStr: String; var lineBuf: String
    var lineBytes: ArrayList<UInt8>; var shouldClose: Bool; var delayClose: Bool
    var floodBytes: Int64; var floodTime: Int64
    public init(s: TcpSocket) {
        this.socket = s; this.alive = mgmtime(); this.outStr = ""; this.lineBuf = ""
        this.lineBytes = ArrayList<UInt8>()
        this.shouldClose = false; this.delayClose = false
        this.floodBytes = 0; this.floodTime = mgmtime()
    }
    public open func handleLine(_l: String): Unit {}
    public open func handleRawLine(_b: ArrayList<UInt8>): Unit {}
    public open func onConnect(): Unit {}
    public open func onDisconnect(): Unit {}
}

