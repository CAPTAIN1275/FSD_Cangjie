package mysql.driver

import std.database.sql

/**
 * 执行 Select/Query 语句返回结果的列信息
 */
public class ColumnInfo <: sql.ColumnInfo {
    public var _table: String = ""
    public var _name: String = ""
    public var _length: UInt32 = 0 // 字段长度，使用32位无符号整数表示
    public var _flags: UInt16 = 0 // 字段的标志位，使用fieldFlag类型表示
    public var _field: UInt8 = 0 // 字段的类型，使用fieldType类型表示
    public var _decimals: UInt8 = 0 // 字段的小数位数，使用8位无符号整数表示
    public var _charSet: UInt8 = 0 // 字段的字符集，使用8位无符号整数表示

    /*
     * 列名或者别名
     */
    public prop name: String {
        get() {
            return this._name
        }
    }

    /*
     * 列类型名称，如果在SqlDataType中定义
     * 返回SqlDataType.toString(),如果未在SqlDataType中定义，由数据库驱动定义
     */
    public prop typeName: String {
        get() {
            return match (this._field) {
                case 0x00 => "DECIMAL" // 精确小数类型（DECIMAL 或 NUMERIC）
                case 0x01 => "TINY" // TINYINT（1 字节整数）
                case 0x02 => "SHORT" // SMALLINT（2 字节整数）
                case 0x03 => "LONG" // INT（4 字节整数）
                case 0x04 => "FLOAT" // 单精度浮点数（FLOAT）
                case 0x05 => "DOUBLE" // 双精度浮点数（DOUBLE）
                case 0x06 => "NULL" // 表示 NULL 值（不是数据类型本身）
                case 0x07 => "TIMESTAMP" // 时间戳（自动更新的时间值）
                case 0x08 => "LONGLONG" // BIGINT（8 字节整数）
                case 0x09 => "INT24" // MEDIUMINT（3 字节整数）
                case 0x0A => "DATE" // 日期类型（YYYY-MM-DD）
                case 0x0B => "TIME" // 时间类型（HH:MM:SS）
                case 0x0C => "DATETIME" // 日期+时间类型（YYYY-MM-DD HH:MM:SS）
                case 0x0D => "YEAR" // 年份类型（YEAR(4)）
                case 0x0E => "NEWDATE" // 内部使用的新日期格式
                case 0x0F => "VARCHAR" // 可变长度字符串（VARCHAR）
                case 0x10 => "BIT" // 位字段类型（BIT(M)）
                case 0x11 => "TIMESTAMP_V2" // 新版本的时间戳（支持更高精度）
                case 0x12 => "DATETIME_V2" // 新版本的 DATETIME（支持微秒）
                case 0x13 => "TIME_V2" // 新版本的 TIME（支持微秒）
                case 0x14 => "JSON" // JSON 数据类型
                case 0xF3 => "INVALID" // 无效类型
                case 0xF4 => "BOOLEAN" // 布尔类型（TINYINT(1) 的别名）
                case 0xF5 => "JSON" // JSON 类型（兼容旧协议）
                case 0xF6 => "NEWDECIMAL" // 更高精度的 DECIMAL 类型
                case 0xF7 => "ENUM" // 枚举类型（ENUM）
                case 0xF8 => "SET" // 集合类型（SET）
                case 0xF9 => "TINY_BLOB" // 小型 BLOB（最大 255 字节）
                case 0xFA => "MEDIUM_BLOB" // 中型 BLOB（最大 16MB）
                case 0xFB => "LONG_BLOB" // 大型 BLOB（最大 4GB）
                case 0xFC => "BLOB" // 普通 BLOB（根据长度判断大小）
                case 0xFD => "VAR_STRING" // 可变长字符串（CHAR 和 VARCHAR 的通用表示）
                case 0xFE => "STRING" // 固定长度字符串（CHAR）
                case 0xFF => "GEOMETRY" // 几何类型（空间数据类型）
                case _ => "UNKNOWN" // 未知或未定义类型
            }
        }
    }

    /*
     * 列值的最大显示长度，如果无限制，则应该返回Int64.Max（仍然受数据库的限制）
     */
    public override prop displaySize: Int64 {
        get() {
            return Int64(this._length) + Int64(this._decimals)
        }
    }

    /**
     * 获取列值大小。
     */
    public prop length: Int64 {
        get() {
            return Int64(this._length)
        }
    }

    /*
     * 列值的小数长度，如果无小数部分，返回0
     */
    public prop scale: Int64 {
        get() {
            return Int64(this._decimals)
        }
    }

    /*
     * 列值是否允许数据库Null值
     */
    public override prop nullable: Bool {
        get() {
            return this._flags % 2 != 0
        }
    }
}
