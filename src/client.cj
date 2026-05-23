package FSD_Cangjie

var rootClient: ?Client = None

public class Client {
    var callsign: String; var cid: String; var realname: String
    var password: String; var `type`: Int32; var rating: Int32; var protocol: Int32
    var lat: Float64; var lon: Float64; var altitude: Int32; var groundspeed: Int32
    var pbh: UInt32; var transponder: Int32; var frequency: Int32
    var facilitytype: Int32; var visualrange: Int32
    var simtype: Int32
    var fd: Int32; var ip: String; var alive: Int64; var startTime: Int64
    var location: ?Server; var plan: ?FlightPlan
    var next: ?Client = None; var prev: ?Client = None

    public init(callsign: String, cid: String, realname: String, password: String,
                `type`: Int32, rating: Int32, protocol: Int32) {
        this.callsign = callsign; this.cid = cid; this.realname = realname
        this.password = password; this.`type` = `type`; this.rating = rating
        this.protocol = protocol; this.lat = 0.0; this.lon = 0.0
        this.altitude = 0; this.groundspeed = 0; this.pbh = 0
        this.transponder = 0; this.frequency = 0; this.facilitytype = 0
        this.visualrange = 0; this.fd = -1; this.ip = ""
        this.simtype = 0
        this.alive = mgmtime(); this.startTime = mgmtime()
        this.location = None; this.plan = None
    }
    public func touch(): Unit { this.alive = mgmtime() }
    public func isAtc(): Bool { return this.`type` == CLIENT_ATC }
    public func isPilot(): Bool { return this.`type` == CLIENT_PILOT }
}

func addClient(c: Client): Unit {
    match (rootClient) {
        case Some(r) =>
            var last = r
            while (true) {
                match (last.next) {
                    case Some(n) => last = n
                    case None => break
                }
            }
            last.next = c; c.prev = last
        case None => rootClient = c
    }
}

func removeClient(c: Client): Unit {
    match (c.prev) {
        case Some(p) => p.next = c.next
        case None => rootClient = c.next
    }
    match (c.next) {
        case Some(n) => n.prev = c.prev
        case None => ()
    }
}

func getClient(callsign: String): ?Client {
    var cur = rootClient
    while (true) {
        match (cur) {
            case Some(cl) =>
                if (cl.callsign == callsign) { return cur }
                cur = cl.next
            case None => break
        }
    }
    return None
}

func clientCount(): Int32 {
    var count: Int32 = 0
    var cur = rootClient
    while (true) {
        match (cur) {
            case Some(cl) =>
                count += 1; cur = cl.next
            case None => break
        }
    }
    return count
}
