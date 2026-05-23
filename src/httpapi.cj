package FSD_Cangjie

public class HttpApi {
    var port: Int32; var running: Bool
    public init(port: Int32) { this.port = port; this.running = false }
    public func start(): Unit { this.running = true; dolog(L_INFO, "HTTP API starting on port ${this.port}") }
    public func stop(): Unit { this.running = false }

    public func handleGetStatus(): String {
        return "{\"status\":\"online\",\"version\":\"${VERSION}\",\"clients\":${clientCount()},\"servers\":${serverCount()}}"
    }

    public func handleSubmitFlightPlan(query: String): (Int32, String) {
        if (query == "") { return (400, "{\"error\":\"Missing parameters\"}") }
        var callsign = ""; var cid = ""; var fpData = ""
        for (param in splitStr(query, "&")) {
            let pair = splitStr(param, "=")
            if (pair.size == 2) {
                if (pair[0] == "callsign") { callsign = pair[1] }
                else if (pair[0] == "cid") { cid = pair[1] }
                else if (pair[0] == "fp_data") { fpData = pair[1] }
            }
        }
        if (callsign == "" || cid == "" || fpData == "") { return (400, "{\"error\":\"Missing required fields\"}") }
        match (gMysql) {
            case Some(db) => if (db.saveFlightPlan(callsign, cid, fpData)) { return (201, "{\"status\":\"success\"}") }; return (500, "{\"error\":\"Failed\"}")
            case None => return (500, "{\"error\":\"DB unavailable\"}")
        }
    }

    public func handleGetFlightPlan(callsign: String): (Int32, String) {
        match (gMysql) {
            case Some(db) => match (db.getFlightPlan(callsign)) {
                case Some(fp) => return (200, "{\"status\":\"success\",\"fp_data\":\"${fp}\"}"); case None => return (404, "{\"error\":\"Not found\"}")
            }
            case None => return (500, "{\"error\":\"DB unavailable\"}")
        }
    }

    public func handleDeleteFlightPlan(callsign: String): (Int32, String) {
        match (gMysql) {
            case Some(db) => if (db.deleteFlightPlan(callsign)) { return (200, "{\"status\":\"success\"}") }; return (500, "{\"error\":\"Failed\"}")
            case None => return (500, "{\"error\":\"DB unavailable\"}")
        }
    }

    public func run(): Int32 { return 0 }
}
