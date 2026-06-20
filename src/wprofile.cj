// wprofile.cj — 天气剖面系统（METAR 结构化解析）
package FSD_Cangjie

import std.collection.*

public class CloudLayer {
    var coverage: Int32
    var ceiling: Int32
    var floor: Int32
    public init(cov: Int32, ceil: Int32, flr: Int32) {
        this.coverage = cov; this.ceiling = ceil; this.floor = flr
    }
}

public class WindLayer {
    var direction: Int32; var speed: Int32; var gusting: Int32
    var ceiling: Int32; var floor: Int32; var turbulence: Int32
    public init(dir: Int32, spd: Int32, gst: Int32, ceil: Int32, flr: Int32, turb: Int32) {
        this.direction = dir; this.speed = spd; this.gusting = gst
        this.ceiling = ceil; this.floor = flr; this.turbulence = turb
    }
}

public class TempLayer {
    var ceiling: Int32; var temp: Int32
    public init(ceil: Int32, tmp: Int32) { this.ceiling = ceil; this.temp = tmp }
}

public class WeatherProfile {
    var icao: String; var raw: String; var time: Int64
    var winds: ArrayList<WindLayer>; var clouds: ArrayList<CloudLayer>; var temps: ArrayList<TempLayer>
    var visibility: Float64; var barometer: Int64; var dewpoint: Int64; var temperature: Int64
    var windDir: Int64; var windSpeed: Int64; var windGust: Int64
    var flightRule: String

    public init(icao: String, raw: String) {
        this.icao = icao; this.raw = raw; this.time = mgmtime()
        this.winds = ArrayList<WindLayer>(); this.clouds = ArrayList<CloudLayer>(); this.temps = ArrayList<TempLayer>()
        this.visibility = 10.0; this.barometer = 10130; this.dewpoint = 0; this.temperature = 0
        this.windDir = 0; this.windSpeed = 0; this.windGust = 0; this.flightRule = "VFR"
        parse()
    }

    private func parse(): Unit {
        let parts = splitStr(this.raw, " ")
        for (i in 0..parts.size) {
            let p = parts[Int64(i)]
            if (p.size >= 5 && p.endsWith("KT") && p.toRuneArray()[0] >= r'0' && p.toRuneArray()[0] <= r'9') {
                let gPos = p.indexOf(r'G')
                match (gPos) {
                    case Some(g) =>
                        this.windDir = parseInt64(substrTo(p, 3))
                        this.windSpeed = parseInt64(substrTo(substrFrom(p, 3), Int64(g) - 3))
                        this.windGust = parseInt64(substrTo(substrFrom(p, Int64(g) + 1), p.size - Int64(g) - 3))
                    case None =>
                        this.windDir = parseInt64(substrTo(p, 3))
                        this.windSpeed = parseInt64(substrTo(substrFrom(p, 3), p.size - 5))
                }
            }
            if (p.contains("/") && p.size >= 3 && p.toRuneArray()[0] >= r'0') {
                let sPos = p.indexOf(r'/')
                match (sPos) {
                    case Some(sp) =>
                        this.temperature = parseInt64(substrTo(p, sp)) * 10
                        this.dewpoint = parseInt64(substrFrom(p, sp + 1)) * 10
                    case None => ()
                }
            }
            if (p.startsWith("A") && p.size == 5) { this.barometer = (parseInt64(substrFrom(p, 1)) * 3386) / 100 }
            else if (p.startsWith("Q") && p.size >= 4) { this.barometer = parseInt64(substrFrom(p, 1)) * 10 }
            if (p.startsWith("FEW") || p.startsWith("SCT") || p.startsWith("BKN") || p.startsWith("OVC")) {
                let cov: Int32 = if (p.startsWith("FEW")) { 1 } else if (p.startsWith("SCT")) { 2 } else if (p.startsWith("BKN")) { 3 } else { 4 }
                let ceil: Int32 = if (p.size > 3) { Int32(parseInt64(substrFrom(p, 3)) * 100) } else { 0 }
                this.clouds.add(CloudLayer(cov, ceil, 0))
            }
        }
        if (this.clouds.size > 0) {
            let lc = Int64(this.clouds[0].ceiling)
            if (lc < 500 || this.visibility < 1.0) { this.flightRule = "LIFR" }
            else if (lc < 1000 || this.visibility < 3.0) { this.flightRule = "IFR" }
            else if (lc <= 3000 || this.visibility <= 5.0) { this.flightRule = "MVFR" }
        }
    }

    public func toWxMessage(callsign: String): String {
        return "#WX${this.icao}:${this.windDir}:${this.windSpeed}:${this.windGust}:${this.visibility}:${this.flightRule}:${this.raw}"
    }
    public func toCdMessage(): String {
        var msg = "#CD"
        for (i in 0..this.clouds.size) { let c = this.clouds[Int64(i)]; msg += "${c.coverage}:${c.ceiling}:${c.floor}" + if (i < this.clouds.size - 1) { ":" } else { "" } }
        return msg
    }
    public func toWdMessage(): String {
        var msg = "#WD"
        for (i in 0..this.winds.size) { let w = this.winds[Int64(i)]; msg += "${w.direction}:${w.speed}:${w.gusting}:${w.ceiling}:${w.floor}:${w.turbulence}" + if (i < this.winds.size - 1) { ":" } else { "" } }
        return msg
    }
}
