package admin

import std.net.*
import std.collection.*
import std.convert.*
import std.time.*

// FSD 3010 系统管理接口客户端（设备端工具）
// 用法: ./sys3010 [host] [port] [pwd] [command]
// 例:  ./sys3010                          -> 127.0.0.1:3010 disable help
//      ./sys3010 127.0.0.1 3010 disable clients
main(args: Array<String>): Int64 {
    // 注意：仓颉 main 的 args 不含程序名，args[0] 是第一个用户参数
    var host = "127.0.0.1"
    var port: UInt16 = 3010
    var pwd = "disable"
    var cmd = "help"
    if (args.size == 1) {
        cmd = args[0]                       // 简写: ./admin clients
    } else if (args.size >= 2) {
        host = args[0]
        port = UInt16(Int64.parse(args[1]))
        if (args.size >= 3) { pwd = args[2] }
        if (args.size > 3) {
            let sb = StringBuilder()
            for (i in 3..args.size) {
                if (i > 3) { sb.append(" ") }
                sb.append(args[i])
            }
            cmd = sb.toString()
        }
    }

    let sock = TcpSocket(host, port)
    try {
        sock.connect()
    } catch (e: Exception) {
        eprintln("connect failed: ${e}")
        return 2
    }
    sock.readTimeout = Duration.second * 2
    var buf = Array<UInt8>(8192, repeat: 0u8)

    drain(sock, buf)                              // banner
    sock.write("pwd ${pwd}\n".toArray())          // 认证
    drain(sock, buf)
    sock.write("${cmd}\n".toArray())              // 命令
    drain(sock, buf)
    sock.write("quit\n".toArray())
    sock.close()
    return 0
}

func drain(sock: TcpSocket, buf: Array<UInt8>): Unit {
    var go = true
    while (go) {
        try {
            let n = sock.read(buf)
            if (n <= 0) {
                go = false
            } else {
                print(String.fromUtf8(buf[0..n]))
            }
        } catch (_: Exception) {
            go = false
        }
    }
}
