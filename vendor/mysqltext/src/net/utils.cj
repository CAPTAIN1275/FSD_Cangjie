package mysql.net

import std.collection.*
import std.database.sql.SqlException
import std.collection.*
import stdx.crypto.keys.*
import stdx.crypto.digest.*
import std.io.*
import std.binary.*

func sha256(scramble: Array<UInt8>, password: String): Array<UInt8> {
    var sha256Instance = SHA256()
    sha256Instance.write(password.toArray())
    var message1: Array<Byte> = sha256Instance.finish()
    sha256Instance.reset()

    sha256Instance.write(message1)
    var message1Hash: Array<Byte> = sha256Instance.finish()
    sha256Instance.reset()

    sha256Instance.write(message1Hash)
    sha256Instance.write(scramble)
    var message2: Array<Byte> = sha256Instance.finish()

    var i = 0
    for (_ in message1) {
        message1[i] ^= message2[i]
        i++
    }

    return message1
}

func sha1(scramble: Array<UInt8>, password: String): Array<UInt8> {
    var sha1Instance = SHA1()
    sha1Instance.write(password.toArray())
    var stage1: Array<Byte> = sha1Instance.finish()
    sha1Instance.reset()

    sha1Instance.write(stage1)
    var hash: Array<Byte> = sha1Instance.finish()
    sha1Instance.reset()

    sha1Instance.write(scramble)
    sha1Instance.write(hash)
    var md: Array<Byte> = sha1Instance.finish()

    var i = 0
    for (_ in scramble) {
        md[i] ^= stage1[i]
        i++
    }

    return md
}

func encryptPassword(password: String, seed: Array<UInt8>, pub: RSAPublicKey): Array<UInt8> {
    var plain = ArrayList<UInt8>()
    plain.add(all:password)
    plain.add(0x00)
    var i = 0
	for (_ in plain) {
		let j = i % seed.size
		plain[i] ^= seed[j]
        i++
	}

    var inBuf = ByteBuffer()
    inBuf.write(plain.toArray())

    var outBuf = ByteBuffer()

	pub.encrypt(inBuf, outBuf,padType: PadOption.OAEP(OAEPOption(SHA1(), SHA1(), label: "")))

    return outBuf.bytes()
}