package mysql.net

import std.net.StreamingSocket
import std.collection.ArrayList

/**
 * 网络读缓冲区, 无关协议的缓冲区
 * 设计上, 可以用到任意网络应用上
 * TODO buf属性还不知道怎么复用内存块
*/
public class Buff {
    private let socket: StreamingSocket

    // 保存缓从区的数据, 数据读取不会修改 size, 只会修改 this.length
    private var buf = ArrayList<Byte>()

    // 当前buf读取位置
    var idx: Int = 0
    // this.buf 剩余未读取长度
    var length: Int = 0
    // 连接是否已损坏（读写超时/断开）
    public var broken: Bool = false

    public init(socket: StreamingSocket) {
        this.socket = socket
    }
    
    // 读入缓冲区, 至少读取到need长度的数据
    public func fill(need: Int) {
        if (this.length > 0) {
            this.buf = this.buf[this.idx..]
        } else {
            this.length = 0
            this.buf = ArrayList<Byte>()
        }

        this.idx = 0

        var n = this.length

        do {
            try {
                // 读超时 30 秒：避免对端异常时读操作永久阻塞，把连接池挂死
                this.socket.readTimeout = Duration.second * 30

                let rs = Array<Byte>(4096, repeat: 0)
                let nn = this.socket.read(rs) // 无法使用可变长度的数组进行读取
                n += nn

                this.buf.add(all:rs[0..nn])
            } catch (e: Exception) {
                // 标记连接损坏，交由上层丢弃该连接
                this.broken = true
                throw e
            }

            if (n < need) {
                continue
            }
            this.length = n
            return
        } while (true)
    }
    
    // 按照顺序缓冲区读取指定长度的数据
    public func readNext(need: Int): Array<Byte> {
        if (this.length < need) {
            // 缓冲区数据不够, 填充缓冲区
            this.fill(need)
        }

        let offset = this.idx
        this.idx += need
        this.length -= need
        return this.buf[offset..this.idx].toArray()
    }

    public func write(data: Array<Byte>) {
        this.socket.write(data)
    }
}