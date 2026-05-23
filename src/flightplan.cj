package FSD_Cangjie

public class FlightPlan {
    var callsign: String; var cid: String; var revision: Int32; var `type`: Rune
    var aircraft: String; var tascruise: Int32; var depAirport: String
    var destAirport: String; var altAirport: String
    var depTime: Int32; var actDepTime: Int32
    var hrsEnroute: Int32; var minEnroute: Int32
    var hrsFuel: Int32; var minFuel: Int32; var altitude: Int32
    var remarks: String; var route: String

    public init() {
        this.callsign = ""; this.cid = ""; this.revision = 0; this.`type` = r'I'
        this.aircraft = ""; this.tascruise = 0; this.depAirport = ""
        this.destAirport = ""; this.altAirport = ""; this.depTime = 0
        this.actDepTime = 0; this.hrsEnroute = 0; this.minEnroute = 0
        this.hrsFuel = 0; this.minFuel = 0; this.altitude = 0
        this.remarks = ""; this.route = ""
    }

    public static func parse(data: String): FlightPlan {
        let parts = splitStr(data, ":"); let fp = FlightPlan()
        if (parts.size > 0) { fp.aircraft = parts[0] }
        if (parts.size > 1) { fp.tascruise = parseInt32(parts[1]) }
        if (parts.size > 2) { fp.depAirport = parts[2] }
        if (parts.size > 3) { fp.depTime = parseInt32(parts[3]) }
        if (parts.size > 4) { fp.actDepTime = parseInt32(parts[4]) }
        if (parts.size > 5) { fp.altitude = parseInt32(parts[5]) }
        if (parts.size > 6) { fp.destAirport = parts[6] }
        if (parts.size > 7) { fp.hrsEnroute = parseInt32(parts[7]) }
        if (parts.size > 8) { fp.minEnroute = parseInt32(parts[8]) }
        if (parts.size > 9) { fp.hrsFuel = parseInt32(parts[9]) }
        if (parts.size > 10) { fp.minFuel = parseInt32(parts[10]) }
        if (parts.size > 11) { fp.altAirport = parts[11] }
        if (parts.size > 12) { fp.remarks = parts[12] }
        if (parts.size > 13) { fp.route = parts[13] }
        return fp
    }

    public func serialize(): String {
        return "${aircraft}:${tascruise}:${depAirport}:${actDepTime}:${revision}:${altitude}:${destAirport}:${hrsEnroute}:${minEnroute}:${hrsFuel}:${minFuel}:${altAirport}:${remarks}:${route}"
    }
}
