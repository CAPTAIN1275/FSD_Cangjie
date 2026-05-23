package FSD_Cangjie

import std.collection.*

public class MetarManager {
    var source: Int32; var profiles: HashMap<String, WeatherProfile>; var lastRefresh: Int64
    public init() { this.source = SOURCE_NETWORK; this.profiles = HashMap<String, WeatherProfile>(); this.lastRefresh = 0 }
    public func getMetar(icao: String): ?String {
        match (this.profiles.get(icao)) { case Some(p) => return p.data; case None => return None }
    }
    public func setMetar(icao: String, data: String): Unit {
        this.profiles[icao] = WeatherProfile(icao, data, mgmtime())
    }
    public func deleteMetar(icao: String): Unit { this.profiles.remove(icao) }
    public func run(): Int32 { return 0 }

    public func requestMetar(client: String, metar: String, parsed: Int32, fd: Int32): Unit {
        dolog(L_INFO, "METAR request: ${metar} from ${client}")
    }
}

public class WeatherProfile {
    var icao: String; var data: String; var updated: Int64
    public init(icao: String, data: String, updated: Int64) { this.icao = icao; this.data = data; this.updated = updated }
}
