package FSD_Cangjie

import std.collection.*

var clientMap = HashMap<String, Client>()
// CID→呼号 索引，用于 O(1) CID 查找
var cidIndex = HashMap<String, String>()

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
        this.location = None; this.plan = None
    }
    public func touch(): Unit { this.alive = mgmtime() }
    public func isAtc(): Bool { return this.`type` == CLIENT_ATC }
    public func isPilot(): Bool { return this.`type` == CLIENT_PILOT }
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

// O(1) HashMap 替代 O(n) 链表
func addClient(c: Client): Bool {
    let key = c.callsign.toUpper()
    match (clientMap.get(key)) {
        case Some(_) => return false
        case None => ()
    }
    clientMap[key] = c
    cidIndex[c.cid] = key
    return true
}

func removeClient(c: Client): Unit {
    clientMap.remove(c.callsign.toUpper())
    cidIndex.remove(c.cid)
}

func getClient(callsign: String): ?Client {
    return clientMap.get(callsign.toUpper())
}

// O(1) CID 查找（通过 cidIndex）
func getClientByCid(cid: String): ?Client {
    match (cidIndex.get(cid)) {
        case Some(cs) => return clientMap.get(cs)
        case None => return None
    }
}

func clientCount(): Int64 {
    return clientMap.size
}
