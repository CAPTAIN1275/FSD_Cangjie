package FSD_Cangjie

import std.collection.*
import std.collection.concurrent.*
import std.sync.*

// 并发安全注册表：读多写少（每个数据包都 getClient），用 ConcurrentHashMap 免锁读。
var clientMap = ConcurrentHashMap<String, Client>()
var cidIndex = ConcurrentHashMap<String, String>()

public class Client {
    var callsign: String; var cid: String; var realname: String
    var password: String; var `type`: Int32; var rating: Int32; var protocol: Int32
    var lat: Float64; var lon: Float64; var altitude: Int32; var groundspeed: Int32
    var pbh: UInt32; var transponder: Int32; var frequency: Int32
    var facilitytype: Int32; var visualrange: Int32
    var simtype: Int32
    var fd: Int32; var ip: String; var alive: Int64; var startTime: Int64
    var prevLat: Float64; var prevLon: Float64
    var headingCalc: Float64
    var location: ?Server; var plan: ?FlightPlan
    var planLockedBy: String

    public init(callsign: String, cid: String, realname: String, password: String,
                _type: Int32, rating: Int32, protocol: Int32) {
        this.callsign = callsign; this.cid = cid; this.realname = realname
        this.password = password; this.`type` = _type; this.rating = rating
        this.protocol = protocol; this.lat = 0.0; this.lon = 0.0
        this.altitude = 0; this.groundspeed = 0; this.pbh = 0
        this.transponder = 0; this.frequency = 0; this.facilitytype = 0
        this.visualrange = 0; this.fd = -1; this.ip = ""
        this.simtype = 0
        this.prevLat = 0.0; this.prevLon = 0.0; this.headingCalc = 0.0
        this.alive = mgmtime(); this.startTime = mgmtime()
        this.location = None; this.plan = None; this.planLockedBy = ""
    }
    public func touch(): Unit { this.alive = mgmtime() }
    public func isAtc(): Bool { return this.`type` == CLIENT_ATC }
    public func isPilot(): Bool { return this.`type` == CLIENT_PILOT }
    public func positionKnown(): Bool { return this.lat != 0.0 || this.lon != 0.0 }
    public func getrange(): Int32 {
        if (this.isAtc()) { return this.visualrange }
        if (this.rating >= LEV_CTLFLN) { return 200 }
        if (this.rating >= LEV_APPTRAIN) { return 150 }
        if (this.rating >= LEV_CERTPILOT) { return 100 }
        return 50
    }
    public func distanceNM(other: Client): Float64 {
        return calcNMDistance(this.lat, this.lon, other.lat, other.lon)
    }
}

// O(1) 并发注册表：addIfAbsent 保证同呼号原子去重
func addClient(c: Client): Bool {
    let key = c.callsign.toUpper()
    if (clientMap.size >= Int64(MAX_CLIENTS)) { return false }
    if (clientMap.addIfAbsent(key, c).isSome()) { return false }
    cidIndex.add(c.cid, key)
    return true
}

func removeClient(c: Client): Unit {
    clientMap.remove(c.callsign.toUpper())
    cidIndex.remove(c.cid)
}

// C 版 getclient(name): 按 callsign 或 cid 查找（免锁读）
func getClient(name: String): ?Client {
    match (clientMap.get(name.toUpper())) {
        case Some(c) => Some(c)
        case None => getClientByCid(name)
    }
}

// O(1) CID 查找（通过 cidIndex）
func getClientByCid(cid: String): ?Client {
    match (cidIndex.get(cid)) {
        case Some(cs) => clientMap.get(cs)
        case None => None
    }
}

func clientCount(): Int64 { return clientMap.size }

// 获取所有 key 的快照（主循环遍历用）
func getClientKeys(): ArrayList<String> {
    let keys = ArrayList<String>()
    for (kv in clientMap) { keys.add(kv[0]) }
    keys
}
