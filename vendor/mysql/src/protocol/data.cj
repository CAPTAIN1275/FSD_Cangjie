package mysql.protocol

import std.collection.*
import std.database.*
import std.io.*
import std.binary.*
import std.time.*
import std.math.numeric.*

public interface SqlData {
    func writeSqlType(pack: ArrayList<UInt8>): Unit

    func writeSqlValue(pack: ArrayList<UInt8>): Unit
}

public class SqlNull <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeNULL, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        
    }
}

extend String <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeVarString, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        pack.add(all: appendLengthEncodedInteger(this.size))
        pack.add(all: this)
    }
}

extend Bool <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeBLOB, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        pack.add(all: match (this) {
            case true => [1]
            case false => [0]
        })
    }
}

extend Int8 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeTiny, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend UInt8 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeTiny, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend Int16 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeShort, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend UInt16 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeShort, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend Int32 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeLong, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend UInt32 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeLong, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend Int64 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeLongLong, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend UInt64 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeLongLong, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend Float16 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeFloat, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend Float32 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeFloat, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend Float64 <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [UInt8(FieldTypeFloat), 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let vByte = Array<UInt8>(8, repeat: 0)
        this.writeLittleEndian(vByte)
        pack.add(all: vByte)
    }
}

extend DateTime <: SqlData {
    public func writeSqlType(pack: ArrayList<UInt8>): Unit {
        pack.add(all: [FieldTypeString, 0x00])
    }

    public func writeSqlValue(pack: ArrayList<UInt8>): Unit {
        let str = this.toString()

        pack.add(all: appendLengthEncodedInteger(str.size))
        pack.add(all: str)
    }
}
