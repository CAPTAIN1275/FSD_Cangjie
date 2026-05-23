package FSD_Cangjie

import std.collection.*

var rootServer: ?Server = None
var myServer: ?Server = None

public class Server {
    var ident: String; var name: String; var email: String
    var hostname: String; var version: String; var location: String
    var flags: Int32; var fd: Int32; var port: Int32; var ip: String
    var alive: Int64; var startTime: Int64
    var packetCount: Int64; var feedBytes: Int64; var lag: Int64
    var next: ?Server = None; var prev: ?Server = None
    var routes: HashMap<String, ServerRoute>

    public init(ident: String, name: String, email: String, hostname: String,
                version: String, flags: Int32, location: String) {
        this.ident = ident; this.name = name; this.email = email
        this.hostname = hostname; this.version = version; this.flags = flags
        this.location = location; this.fd = -1; this.port = 0; this.ip = ""
        this.alive = mgmtime(); this.startTime = mgmtime()
        this.packetCount = 0; this.feedBytes = 0; this.lag = 0
        this.routes = HashMap<String, ServerRoute>()
    }
    public func configure(name: String, email: String, hostname: String,
                          version: String, location: String): Unit {
        this.name = name; this.email = email; this.hostname = hostname
        this.version = version; this.location = location
    }
    public func touch(): Unit { this.alive = mgmtime() }
    public func isSilent(): Bool { return (this.flags & SERVER_SILENT) != 0 }
    public func isMetar(): Bool { return (this.flags & SERVER_METAR) != 0 }
}

public class ServerRoute {
    var via: Server; var hops: Int32; var packetCount: Int64
    public init(via: Server, hops: Int32, packetCount: Int64) {
        this.via = via; this.hops = hops; this.packetCount = packetCount
    }
}

func addServer(s: Server): Unit {
    match (rootServer) {
        case Some(r) =>
            var last = r
            while (true) {
                match (last.next) {
                    case Some(n) => last = n
                    case None => break
                }
            }
            last.next = s; s.prev = last
        case None => rootServer = s
    }
}

func removeServer(s: Server): Unit {
    match (s.prev) {
        case Some(p) => p.next = s.next
        case None => rootServer = s.next
    }
    match (s.next) {
        case Some(n) => n.prev = s.prev
        case None => ()
    }
}

func getServer(ident: String): ?Server {
    var cur = rootServer
    while (true) {
        match (cur) {
            case Some(sv) =>
                if (sv.ident == ident) { return cur }
                cur = sv.next
            case None => break
        }
    }
    return None
}

func serverCount(): Int32 {
    var count: Int32 = 0
    var cur = rootServer
    while (true) {
        match (cur) {
            case Some(sv) =>
                count += 1; cur = sv.next
            case None => break
        }
    }
    return count
}
