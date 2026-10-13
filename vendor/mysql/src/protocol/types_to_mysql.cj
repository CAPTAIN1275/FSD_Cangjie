package mysql.protocol

import std.convert.*
import std.binary.*
import std.collection.*
import std.io.InputStream
import std.io.ByteBuffer
import std.time.*

// https://dev.mysql.com/doc/dev/mysql-server/latest/namespacedd.html#a434db23351409cb0730fdbdfc144e8f8

// const FieldTypeDecimal: UInt8 = 0
const FieldTypeTiny: UInt8 = 1
const FieldTypeShort: UInt8 = 2
const FieldTypeLong: UInt8 = 3
const FieldTypeFloat: UInt8 = 4
const FieldTypeDouble: UInt8 = 5
const FieldTypeNULL: UInt8 = 6
// const FieldTypeTimestamp: UInt8 = 7
const FieldTypeLongLong: UInt8 = 8
// const FieldTypeInt24: UInt8 = 9
// const FieldTypeDate: UInt8 = 10
// const FieldTypeTime: UInt8 = 11
// const FieldTypeDateTime: UInt8 = 12
// const FieldTypeYear: UInt8 = 13
// const FieldTypeNewDate: UInt8 = 14
// const FieldTypeVarChar: UInt8 = 15
// const FieldTypeBit: UInt8 = 16
// const FieldTypeJSON: UInt8 = 245
// const FieldTypeNewDecimal: UInt8 = 246
// const FieldTypeEnum: UInt8 = 247
// const FieldTypeSet: UInt8 = 248
// const FieldTypeTinyBLOB: UInt8 = 249
// const FieldTypeMediumBLOB: UInt8 = 250
const FieldTypeLongBLOB: UInt8 = 251
const FieldTypeBLOB: UInt8 = 252
const FieldTypeVarString: UInt8 = 253
const FieldTypeString: UInt8 = 254
// const FieldTypeGeometry: UInt8 = 255


// 用字符串先实现
func toDateTime(paramTypes: ArrayList<UInt8>, paramValues: ArrayList<UInt8>, v: DateTime) {
    paramTypes.add(UInt8(FieldTypeString))
    paramTypes.add(0x00)

    let str = v.toString()
    appendLengthEncodedInteger(paramValues, str.size)
    paramValues.add(all:str)
}
