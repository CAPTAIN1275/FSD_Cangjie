// net.cj — FSD 网络层：C FFI 封装 POSIX socket
// 仓颉 1.1.0 API：acquireArrayRawData / CPointerHandle / CPointer.null()
// 对应 C 版本 interface.cpp / user.cpp 中通过 <sys/socket.h> 直接调用的系统调用

package FSD_Cangjie.fsd

// ============= C FFI 声明 =============

foreign {
    func socket(domain: Int32, type_: Int32, protocol: Int32): Int32
    func close(fd: Int32): Int32
    func bind(sockfd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32
    func listen(sockfd: Int32, backlog: Int32): Int32
    func accept(sockfd: Int32, addr: CPointer<UInt8>, addrlen: CPointer<UInt32>): Int32
    func accept4(sockfd: Int32, addr: CPointer<UInt8>, addrlen: CPointer<UInt32>, flags: Int32): Int32
    func connect(sockfd: Int32, addr: CPointer<UInt8>, addrlen: UInt32): Int32
    func send(sockfd: Int32, buf: CPointer<UInt8>, len: UInt64, flags: Int32): Int64
    func recv(sockfd: Int32, buf: CPointer<UInt8>, len: UInt64, flags: Int32): Int64
    func select(nfds: Int32, readfds: CPointer<UInt8>, writefds: CPointer<UInt8>,
        exceptfds: CPointer<UInt8>, timeout: CPointer<Int64>): Int32
    func fcntl(fd: Int32, cmd: Int32, arg: Int32): Int32
    func setsockopt(sockfd: Int32, level: Int32, optname: Int32,
        optval: CPointer<Int32>, optlen: UInt32): Int32
    func htons(hostshort: UInt16): UInt16
    func htonl(hostlong: UInt32): UInt32
    func ntohs(netshort: UInt16): UInt16
    // errno 必须通过函数读取，不能用 foreign var
    func __errno_location(): CPointer<Int32>
}

// ============= 常量 =============

let AF_INET_SOCK: Int32 = 2
let SOCK_STREAM_SOCK: Int32 = 1
let SOCK_NONBLOCK_FLAG: Int32 = 0x800
let SOL_SOCKET_SOCK: Int32 = 1
let SO_REUSEADDR_SOCK: Int32 = 2
let IPPROTO_TCP_SOCK: Int32 = 6
let TCP_NODELAY_SOCK: Int32 = 1
let F_GETFL: Int32 = 3
let F_SETFL: Int32 = 4
let O_NONBLOCK_SOCK: Int32 = 0x800

// ============= 辅助 =============

// errno 封装
func getErrno(): Int32 {
    return unsafe {
        let loc = __errno_location()
        if (loc.isNotNull()) { loc.read() } else { 0 }
    }
}

// Array→CPointer 安全封装
// CPointer<UInt8> 版本
func withArrayPtrU8(arr: Array<UInt8>, fn: (CPointer<UInt8>) -> Int64): Int64 {
    return unsafe {
        let handle = acquireArrayRawData(arr)
        let result = fn(handle.pointer)
        releaseArrayRawData(handle)
        result
    }
}

func withArrayPtrU8I32(arr: Array<UInt8>, fn: (CPointer<UInt8>) -> Int32): Int32 {
    return unsafe {
        let handle = acquireArrayRawData(arr)
        let result = fn(handle.pointer)
        releaseArrayRawData(handle)
        result
    }
}

// CPointer<UInt32> 版本
func withArrayPtrU32I32(arr: Array<UInt32>, fn: (CPointer<UInt32>) -> Int32): Int32 {
    return unsafe {
        let handle = acquireArrayRawData(arr)
        let result = fn(handle.pointer)
        releaseArrayRawData(handle)
        result
    }
}

// CPointer<Int32> 版本
func withArrayPtrI32(arr: Array<Int32>, fn: (CPointer<Int32>) -> Int32): Int32 {
    return unsafe {
        let handle = acquireArrayRawData(arr)
        let result = fn(handle.pointer)
        releaseArrayRawData(handle)
        result
    }
}

// CPointer<Int64> 版本
func withArrayPtrI64(arr: Array<Int64>, fn: (CPointer<Int64>) -> Int32): Int32 {
    return unsafe {
        let handle = acquireArrayRawData(arr)
        let result = fn(handle.pointer)
        releaseArrayRawData(handle)
        result
    }
}

// ============= 封装函数 =============

func sockCreate(): Int32 {
    return unsafe { socket(AF_INET_SOCK, SOCK_STREAM_SOCK, 0) }
}

// sockBind — 绑定端口
func sockBind(fd: Int32, port: UInt16): Int32 {
    var sa = Array<UInt8>(16, repeat: 0u8)
    let netPort = unsafe { htons(port) }
    sa[0] = UInt8(AF_INET_SOCK & 0xFF)
    sa[1] = UInt8((AF_INET_SOCK >> 8) & 0xFF)
    sa[2] = UInt8(netPort & 0xFF)
    sa[3] = UInt8((netPort >> 8) & 0xFF)

    return withArrayPtrU8I32(sa, { ptr: CPointer<UInt8> =>
        unsafe { bind(fd, ptr, 16u32) }
    })
}

func sockListen(fd: Int32, backlog: Int32): Int32 {
    return unsafe { listen(fd, backlog) }
}

func sockAccept(fd: Int32): Int32 {
    // accept4: 用 dummy 数组代替 null pointer
    let addrArr = Array<UInt8>(16, repeat: 0u8)
    let lenArr = Array<UInt32>(1, repeat: 0u32)
    return unsafe {
        let aHandle = acquireArrayRawData(addrArr)
        let lHandle = acquireArrayRawData(lenArr)
        let result = accept4(fd, aHandle.pointer, lHandle.pointer, SOCK_NONBLOCK_FLAG)
        releaseArrayRawData(aHandle)
        releaseArrayRawData(lHandle)
        result
    }
}

func sockConnect(fd: Int32, host: String, port: UInt16): Int32 {
    var sa = Array<UInt8>(16, repeat: 0u8)
    let netPort = unsafe { htons(port) }
    sa[0] = UInt8(AF_INET_SOCK & 0xFF)
    sa[1] = UInt8((AF_INET_SOCK >> 8) & 0xFF)
    sa[2] = UInt8(netPort & 0xFF)
    sa[3] = UInt8((netPort >> 8) & 0xFF)

    return withArrayPtrU8I32(sa, { ptr: CPointer<UInt8> =>
        unsafe { connect(fd, ptr, 16u32) }
    })
}

func sockSetNonBlock(fd: Int32) {
    let flags = unsafe { fcntl(fd, F_GETFL, 0) }
    unsafe { fcntl(fd, F_SETFL, flags | O_NONBLOCK_SOCK) }
}

func sockSetReuseAddr(fd: Int32) {
    var on = Array<Int32>(1, repeat: 1)
    withArrayPtrI32(on, { ptr: CPointer<Int32> =>
        unsafe { setsockopt(fd, SOL_SOCKET_SOCK, SO_REUSEADDR_SOCK, ptr, 4u32) }
    })
}

func sockSetNoDelay(fd: Int32) {
    var on = Array<Int32>(1, repeat: 1)
    withArrayPtrI32(on, { ptr: CPointer<Int32> =>
        unsafe { setsockopt(fd, IPPROTO_TCP_SOCK, TCP_NODELAY_SOCK, ptr, 4u32) }
    })
}

func sockSend(fd: Int32, data: Array<UInt8>, len: Int32): Int64 {
    return withArrayPtrU8(data, { ptr: CPointer<UInt8> =>
        unsafe { send(fd, ptr, UInt64(len), 0) }
    })
}

func sockRecv(fd: Int32, buf: Array<UInt8>, len: Int32): Int64 {
    return withArrayPtrU8(buf, { ptr: CPointer<UInt8> =>
        unsafe { recv(fd, ptr, UInt64(len), 0) }
    })
}

func sockClose(fd: Int32): Int32 {
    return unsafe { close(fd) }
}

// ============= fd_set（select 用）=============

class FdSet {
    var data: Array<UInt8> = Array<UInt8>(128, repeat: 0u8)

    public init() {}

    func set(fd: Int32) {
        if (fd < 0 || fd >= 1024) { return }
        let byteIdx = Int64(fd) / 8
        let bitIdx = Int64(fd) % 8
        data[byteIdx] = data[byteIdx] | (1u8 << UInt8(bitIdx))
    }

    func isset(fd: Int32): Bool {
        if (fd < 0 || fd >= 1024) { return false }
        let byteIdx = Int64(fd) / 8
        let bitIdx = Int64(fd) % 8
        return (data[byteIdx] & (1u8 << UInt8(bitIdx))) != 0u8
    }

    func zero() {
        for (i in 0..data.size) { data[i] = 0u8 }
    }
}

func sockSelect(maxfd: Int32, rset: FdSet, wset: FdSet, timeoutMs: Int64): Int32 {
    var tv = Array<Int64>(2, repeat: 0)
    let useTimeout: Bool = timeoutMs >= 0
    if (useTimeout) {
        tv[0] = timeoutMs / 1000
        tv[1] = (timeoutMs % 1000) * 1000
    }

    // select 需要同时传三个 Array 的指针，逐个 acquire/release
    // exceptfds 用空 dummy（全零 = 不监听异常）
    var exceptData = Array<UInt8>(128, repeat: 0u8)
    return unsafe {
        let rHandle = acquireArrayRawData(rset.data)
        let wHandle = acquireArrayRawData(wset.data)
        let eHandle = acquireArrayRawData(exceptData)
        let tHandle = if (useTimeout) { acquireArrayRawData(tv) } else {
            acquireArrayRawData(Array<Int64>(2, repeat: 0))
        }

        let result = select(maxfd + 1,
            rHandle.pointer,
            wHandle.pointer,
            eHandle.pointer,
            tHandle.pointer)

        releaseArrayRawData(rHandle)
        releaseArrayRawData(wHandle)
        releaseArrayRawData(eHandle)
        releaseArrayRawData(tHandle)

        result
    }
}
