package FSD_Cangjie

var rootCert: ?Certificate = None

public class Certificate {
    var cid: String; var password: String; var level: Int32
    var created: Int64; var serverIdent: String; var livecheck: Int32
    var next: ?Certificate = None; var prev: ?Certificate = None

    public init(cid: String, password: String, level: Int32, created: Int64, serverIdent: String) {
        this.cid = cid; this.password = password; this.level = level
        this.created = created; this.serverIdent = serverIdent; this.livecheck = 1
    }
    public func configure(password: String, level: Int32, created: Int64, serverIdent: String): Unit {
        this.password = password; this.level = level
        this.created = created; this.serverIdent = serverIdent
    }
}

func addCert(cert: Certificate): Unit {
    match (rootCert) {
        case Some(r) =>
            var last = r
            while (true) {
                match (last.next) {
                    case Some(n) => last = n
                    case None => break
                }
            }
            last.next = cert
            cert.prev = last
        case None => rootCert = cert
    }
}

func removeCert(cert: Certificate): Unit {
    match (cert.prev) {
        case Some(p) => p.next = cert.next
        case None => rootCert = cert.next
    }
    match (cert.next) {
        case Some(n) => n.prev = cert.prev
        case None => ()
    }
}

func getCert(cid: String): ?Certificate {
    var cur = rootCert
    while (true) {
        match (cur) {
            case Some(cert) =>
                if (cert.cid == cid) { return cur }
                cur = cert.next
            case None => break
        }
    }
    return None
}

func markAllCertsInactive(): Unit {
    var cert = rootCert
    while (true) {
        match (cert) {
            case Some(c) =>
                c.livecheck = 0
                cert = c.next
            case None => break
        }
    }
}

func removeInactiveCerts(): Unit {
    var cert = rootCert
    while (true) {
        match (cert) {
            case Some(c) =>
                let next = c.next
                if (c.livecheck == 0) { removeCert(c) }
                cert = next
            case None => break
        }
    }
}
