// stdx_tcp.cj — TcpStream 封装，基于 std.net.Socket（在 FSD_Cangjie 包中直接使用）
package FSD_Cangjie

import std.io.*
import std.net.*

public class TcpListenerX {
    private var serverSocket: TcpServerSocket
    public init(port: UInt16) {
        serverSocket = TcpServerSocket(bindAt: port)
    }
    public func bind(): Unit { serverSocket.bind() }
    public func accept(): TcpStreamX {
        let socket = serverSocket.accept()
        return TcpStreamX(socket)
    }
    public func close(): Unit { serverSocket.close() }
}

public class TcpStreamX {
    private var socket: TcpSocket
    public init(s: TcpSocket) { this.socket = s }
    public func read(buf: Array<UInt8>): Int64 { return socket.read(buf) }
    public func write(buf: Array<UInt8>): Int64 { socket.write(buf); return buf.size }
    public func close(): Unit { socket.close() }
}
