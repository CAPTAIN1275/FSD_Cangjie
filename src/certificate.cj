package FSD_Cangjie

import std.sync.*

var rootCert: ?Certificate = None
var certLock = Mutex()

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
    certLock.lock()
    match (rootCert) {
        case Some(r) =>
            var last = r; var d: Int32 = 0
            while (true) {
                match (last.next) {
                    case Some(n) => last = n; d += 1; if (d > 10000) { certLock.unlock(); return }
                    case None => break
                }
            }
            last.next = cert; cert.prev = last
        case None => rootCert = cert
    }
    certLock.unlock()
}

func removeCert(cert: Certificate): Unit {
    certLock.lock()
    _removeCert(cert)
    certLock.unlock()
}

func _removeCert(cert: Certificate): Unit {
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
    certLock.lock()
    var r: ?Certificate = None
    var cur = rootCert
    while (true) {
        match (cur) {
            case Some(cert) =>
                if (cert.cid == cid) { r = cur; break }
                cur = cert.next
            case None => break
        }
    }
    certLock.unlock()
    return r
}

func markAllCertsInactive(): Unit {
    certLock.lock()
    var cert = rootCert; var d: Int32 = 0
    while (true) {
        match (cert) {
            case Some(c) => c.livecheck = 0; cert = c.next; d += 1; if (d > 10000) { break }
            case None => break
        }
    }
    certLock.unlock()
}

func removeInactiveCerts(): Unit {
    certLock.lock()
    var cert = rootCert; var d: Int32 = 0
    while (true) {
        match (cert) {
            case Some(c) =>
                let next = c.next
                if (c.livecheck == 0) { _removeCert(c) }
                cert = next; d += 1; if (d > 10000) { break }
            case None => break
        }
    }
    certLock.unlock()
}

func certCount(): Int32 {
    certLock.lock()
    var count: Int32 = 0
    var cur = rootCert
    while (true) {
        match (cur) {
            case Some(c) => count += 1; cur = c.next
            case None => break
        }
    }
    certLock.unlock()
    return count
}
