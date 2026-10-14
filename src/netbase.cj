package FSD_Cangjie

import std.net.*
import std.collection.*
import std.collection.concurrent.*
import std.sync.*
import std.time.*

func sendTo(user: NetUser, data: String): Unit {
    user.outStr.push(data.toArray())
}

// 广播热路径专用：编码一次、多个用户共享同一 Array（不复制、不重复分配）
func sendBytesTo(user: NetUser, data: Array<UInt8>): Unit {
    user.outStr.push(data)
}

// 原始字节直写（支持 GBK 等非 UTF-8 编码）
func sendRawTo(user: NetUser, data: ArrayList<UInt8>): Unit {
    user.outStr.push(data.toArray())
}

func toBuf(s: String): Array<UInt8> { return s.toArray() }

// 从 remoteAddress（形如 "1.2.3.4:port"）取 IP 部分，用于白名单比对
func peerIp(socket: TcpSocket): String {
    let a = "${socket.remoteAddress}"
    match (a.indexOf(r':')) {
        case Some(i) => return substrTo(a, i)
        case None => return a
    }
}

// 每用户输出邮箱：线程安全的字节累积缓冲 + 支持 outStr += 运算符。
// 设计对齐 C 原版 absuser::outbuf：所有 sendTo/广播只把字节**累积**进缓冲，
// 绝不阻塞在慢客户端的 socket.write 上；专属 userWriter 线程每次把当前累积的
// 全部字节**一次 write** 发出（合并系统调用），慢客户端只堵住自己。
// 唤醒策略：仅在缓冲由空变非空（或关闭）时投一个令牌到 wake 队列，
// 避免"每条消息一次唤醒"的开销（高负载下每轮广播通常只需一次唤醒）。
// 注意：NetUser 的 outStr 字段类型即本类（保留字段名以复用既有 outStr += 调用点）。
public class OutBuf {
    private let lock = Mutex()
    private let wake = LinkedBlockingQueue<Int64>()   // 唤醒令牌（仅用于阻塞/唤醒 writer）
    private let buf = ArrayList<UInt8>()
    private var closed: Bool = false
    private var overflowed: Bool = false
    private let maxBytes: Int64

    public init(maxMsgs: Int64) {
        // 原语义为"最多缓存 maxMsgs 条消息"，按平均行长近似换算成字节上限
        this.maxBytes = maxMsgs * 64
    }

    public func push(bytes: Array<UInt8>): Unit {
        if (bytes.size == 0) { return }
        var needWake = false
        synchronized(this.lock) {
            if (this.closed || this.overflowed) { return }
            if (this.buf.size + bytes.size > this.maxBytes) {
                // 慢客户端保护：超限即丢弃连接（与原实现一致）
                this.overflowed = true
                this.closed = true
                needWake = true
            } else {
                if (this.buf.size == 0) { needWake = true }
                this.buf.add(all: bytes)
            }
        }
        if (needWake) { this.wake.add(1) }
    }

    // 运算符重载：让既有的 user.outStr += "..." 全部继续可用（+= 自动映射到 +）
    public operator func +(right: String): OutBuf {
        this.push(right.toArray())
        return this
    }

    public func isEmpty(): Bool {
        synchronized(this.lock) { return this.buf.size == 0 && !this.closed }
    }
    public func isOverflowed(): Bool { return this.overflowed }

    // 阻塞等待并一次性取出当前累积的全部字节；返回 None 表示已关闭且冲刷完
    public func take(): Option<Array<UInt8>> {
        synchronized(this.lock) {
            if (this.closed && this.buf.size == 0) { return None }
        }
        this.wake.remove()   // 阻塞直至有令牌（数据或关闭）
        synchronized(this.lock) {
            if (this.buf.size > 0) {
                let d = this.buf.toArray()
                this.buf.clear()
                return Some(d)
            }
            if (this.closed) { return None }
            return Some(Array<UInt8>())   // 误唤醒：writer 跳过此轮
        }
    }

    // 请求 writer 冲刷剩余数据后关闭连接
    public func close(): Unit {
        var needWake = false
        synchronized(this.lock) {
            if (!this.closed) { this.closed = true; needWake = true }
        }
        if (needWake) { this.wake.add(1) }
    }

    // 非阻塞取走当前累积的全部字节（可能为空），供 writer 合并窗口批量收集
    public func drain(): Array<UInt8> {
        synchronized(this.lock) {
            if (this.buf.size == 0) { return Array<UInt8>() }
            let d = this.buf.toArray()
            this.buf.clear()
            return d
        }
    }

    public func closedAndEmpty(): Bool {
        synchronized(this.lock) { return this.closed && this.buf.size == 0 }
    }
}

// 专属写线程：阻塞等待本用户数据并发送；结束后关闭 socket。
// 合并窗口：收到第一批数据后短暂停留 COALESCE_MS，把窗口内到达的后续消息合并成一次 write，
// 大幅减少唤醒次数与系统调用（对齐 C 事件循环的批处理效果）。
let COALESCE_MS: Int64 = 20

func userWriter(user: NetUser): Unit {
    let batch = ArrayList<UInt8>()
    while (true) {
        match (user.outStr.take()) {
            case Some(d) =>
                batch.clear()
                if (d.size > 0) { batch.add(all: d) }
                if (d.size > 0) {
                    // 合并窗口：等待片刻，聚合后续到达的数据
                    sleep(COALESCE_MS * Duration.millisecond)
                    var more = user.outStr.drain()
                    while (more.size > 0) {
                        batch.add(all: more)
                        more = user.outStr.drain()
                    }
                }
                if (batch.size > 0) {
                    try { user.socket.write(batch.toArray()) }
                    catch (e: Exception) {
                        let em = e.toString()
                        // 对端正常断开导致的写失败不打扰日志
                        if (!(em.contains("already closed") || em.contains("closed") || em.contains("reset") || em.contains("Broken pipe") || em.contains("broken pipe") || em.contains("EOF"))) {
                            dolog(L_WARNING, "WRITEERR ${user.id}: ${e}")
                        }
                        user.shouldClose = true
                        break
                    }
                }
                if (user.outStr.closedAndEmpty()) { break }
            case None => break
        }
    }
    try { user.socket.close() } catch (_: Exception) {}
}

public open class NetInterface {
    var port: Int32; var name: String; var desc: String; var runFlag: Bool
    var users: ArrayList<NetUser>
    var usersLock = Mutex()
    var floodLimit: Int32; var outBufLimit: Int32
    public init(port: Int32, name: String, description: String) {
        this.port = port; this.name = name; this.desc = description
        this.runFlag = false; this.users = ArrayList<NetUser>()
        this.floodLimit = 500000; this.outBufLimit = 1000000
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
    public open func checkPeer(_socket: TcpSocket): Bool { return true }

    public func checkTimeouts(timeoutSec: Int64): Unit {
        let now = mgmtime()
        synchronized(this.usersLock) {
            var i: Int64 = 0
            while (i < this.users.size) {
                let u = this.users[Int64(i)]
                if (now - u.lastRecv > timeoutSec) {
                    dolog(L_WARNING, "TIMEOUT ${this.name}: closing user (idle ${now - u.lastRecv}s)")
                    u.shouldClose = true
                    try { u.socket.close() } catch (_: Exception) {}
                    u.outStr.close()
                    this.users.remove(i..(i+1))
                } else { i += 1 }
            }
        }
    }

    private func acceptLoop(): Unit {
        try {
            var ss = TcpServerSocket(bindAt: UInt16(this.port))
            ss.bind()
            println("[${this.desc}] port=${this.port}")
            while (this.runFlag) {
                try {
                    if (this.users.size > Int64(MAX_CLIENTS)) { sleep(100 * Duration.millisecond); continue }
                    let s = ss.accept()
                    if (!this.checkPeer(s)) { dolog(L_INFO, "Connection rejected"); s.close(); continue }
                    s.noDelay = true
                    s.keepAlive = SocketKeepAliveConfig(interval: Duration.second * 5, count: 2)
                    s.readTimeout = Duration.second * 300
                    s.writeTimeout = Duration.second * 30   // 慢/死客户端不永久卡住 writer 线程
                    dolog(L_DEBUG, "New connection on ${this.desc} from ${s.remoteAddress}")
                    let u = createUser(s)
                    u.peerIp = "${s.remoteAddress}"
                    spawn { serve(u) }
                } catch (e: Exception) {
                    if (this.runFlag) { dolog(L_WARNING, "accept error: ${e}") }
                }
            }
            ss.close()
        } catch (e: Exception) { dolog(L_ERR, "BIND FAIL on port ${this.port}: ${e}") }
    }

    public func serve(u: NetUser): Unit {
        spawn { userWriter(u) }
        var buf = Array<UInt8>(4096, repeat: 0u8)
        u.onConnect()
        while (this.runFlag) {
            if (u.shouldClose) { if (currentLogLevel <= L_DEBUG) { dolog(L_DEBUG, "SERVE ${this.name}: shouldClose, break") }; break }
            if (currentLogLevel <= L_DEBUG) { dolog(L_DEBUG, "SERVE ${this.name}: >> waiting for read") }
            var n: Int64 = 0
            var readOk = false
            try { n = u.socket.read(buf); readOk = true }
            catch (_: Exception) { readOk = false }
            if (!readOk) {
                if (currentLogLevel <= L_DEBUG) { dolog(L_DEBUG, "SERVE ${this.name}: read error, closing") }
                break
            }
            if (n <= 0) { dolog(L_DEBUG, "SERVE ${this.name}: read returned ${n}"); break }
            u.lastRecv = mgmtime()
            try {
                if (u.lastRecv % 60 == 0) { dolog(L_DEBUG, "SERVE ${this.name}: alive: ${u.lastRecv}") }
                let now = mgmtime()
                if (now - u.floodTime > 1) { u.floodBytes = 0; u.floodTime = now }
                u.floodBytes += Int64(n)
                if (u.floodBytes > Int64(this.floodLimit) && this.floodLimit > 0) { dolog(L_WARNING, "Flood"); u.shouldClose = true; break }
                for (i in 0..n) {
                    if (u.shouldClose) { break }
                    let b = buf[i]
                    if (b == UInt8(10)) {
                        if (u.lineBytes.size > 0) {
                            let last = u.lineBytes.size - 1
                            if (last >= 0 && u.lineBytes[last] == UInt8(13)) { u.lineBytes.remove(last..last + 1) }
                            // 原始字节包（#TM/#SB）先按字节判定，避免无谓的 UTF-8 解码
                            var isRaw = false
                            if (u.lineBytes.size >= 3) {
                                let b0 = u.lineBytes[0]; let b1 = u.lineBytes[1]; let b2 = u.lineBytes[2]
                                if ((b0 == UInt8(35) && b1 == UInt8(84) && b2 == UInt8(77)) ||
                                    (b0 == UInt8(35) && b1 == UInt8(83) && b2 == UInt8(66))) { isRaw = true }
                            }
                            if (isRaw) {
                                u.handleRawLine(u.lineBytes)
                                if (u.shouldClose) { break }
                            } else {
                                try {
                                    let line = String.fromUtf8(u.lineBytes.toArray())
                                    // 登录包 #AA/#AP 含明文密码，日志脱敏
                                    if (line.startsWith("#AA") || line.startsWith("#AP")) {
                                        if (currentLogLevel <= L_INFO) {
                                            let parts = splitStr(line, ":")
                                            // #AA: [2]=cid [3]=realname [4]=password；#AP: [2]=cid [3]=password
                                            let pwdIdx: Int64 = if (line.startsWith("#AA")) { 4 } else { 3 }
                                            var redacted = parts[0]
                                            for (i in 1..parts.size) {
                                                redacted += ":"
                                                if (i == pwdIdx) { redacted += "*****" } else { redacted += parts[Int64(i)] }
                                            }
                                            dolog(L_INFO, "RX: ${redacted}")
                                        }
                                    } else if (line.startsWith("@") || line.startsWith("%")) {
                                        if (currentLogLevel <= L_DEBUG) { dolog(L_DEBUG, "POS: ${line}") }
                                    } else {
                                        if (currentLogLevel <= L_INFO) { dolog(L_INFO, "RX: ${line}") }
                                    }
                                    if (line != "") {
                                        u.handleLine(line)
                                        if (u.shouldClose) { break }
                                    }
                                } catch (_: Exception) { u.handleRawLine(u.lineBytes) }
                            }
                        }
                        u.lineBytes.clear()
                    } else if (b != UInt8(13)) {
                        if (u.lineBytes.size > 4096) { u.lineBytes.clear(); break }
                        u.lineBytes.add(b)
                    }
                }
            } catch (e: Exception) { dolog(L_WARNING, "SERVE ${this.name} loop exception: ${e}"); break }
        }
        dolog(L_DEBUG, "SERVE ${this.name}: serve loop exited")
        u.onDisconnect()
        u.outStr.close()
        // 关键：无论是否成功登录，都必须把连接从 users 列表移除。
        // 否则未登录连接(扫描器/登录失败/快速掉线)会永久泄漏，累积到 MAX_CLIENTS 后
        // accept 循环会一直跳过接纳 —— 表现为"跑一段时间后莫名其妙连不上"。
        synchronized(this.usersLock) {
            var idx: Int64 = -1
            for (i in 0..this.users.size) {
                if (this.users[Int64(i)].id == u.id) { idx = Int64(i); break }
            }
            if (idx >= 0) { this.users.remove(idx..(idx+1)) }
        }
    }
}

public open class NetUser {
    var id: Int64; var socket: TcpSocket; var alive: Int64; var lastRecv: Int64; var outStr: OutBuf; var lineBuf: String
    var lineBytes: ArrayList<UInt8>; var shouldClose: Bool; var delayClose: Bool
    var floodBytes: Int64; var floodTime: Int64
    var peerIp: String = ""   // 对端 IP（remoteAddress，形如 "1.2.3.4:port"）
    var writeLock = Mutex()
    static var nextId: Int64 = 0
    public init(s: TcpSocket) {
        let now = mgmtime()
        this.id = NetUser.nextId; NetUser.nextId += 1
        this.socket = s; this.alive = now; this.lastRecv = now; this.outStr = OutBuf(20000); this.lineBuf = ""
        this.lineBytes = ArrayList<UInt8>()
        this.shouldClose = false; this.delayClose = false
        this.floodBytes = 0; this.floodTime = now
    }
    public open func handleLine(_l: String): Unit {}
    public open func handleRawLine(_b: ArrayList<UInt8>): Unit {}
    public open func onConnect(): Unit {}
    public open func onDisconnect(): Unit {}
}
