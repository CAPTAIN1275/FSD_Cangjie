package mysql.protocol

/**
 * 所有命令类型
 * https://dev.mysql.com/doc/dev/mysql-server/latest/my__command_8h.html
 */
public enum CommandType {
    | Quit
    | InitDB
    | Query
    | FieldList
    | CreateDB
    | DropDB
    | Refresh
    | Shutdown
    | Statistics
    | ProcessInfo
    | Connect
    | ProcessKill
    | Debug
    | Ping
    | Time
    | DelayedInsert
    | ChangeUser
    | BinlogDump
    | TableDump
    | ConnectOut
    | RegisterSlave
    | StmtPrepare
    | StmtExecute
    | StmtSendLongData
    | StmtClose
    | StmtReset
    | SetOption
    | StmtFetch

    public func value(): Byte {
        match (this) {
            case Quit => 1
            case InitDB => 2
            case Query => 3
            case FieldList => 4
            case CreateDB => 5
            case DropDB => 6
            case Refresh => 7
            case Shutdown => 8
            case Statistics => 9
            case ProcessInfo => 10
            case Connect => 11
            case ProcessKill => 12
            case Debug => 13
            case Ping => 14
            case Time => 15
            case DelayedInsert => 16
            case ChangeUser => 17
            case BinlogDump => 18
            case TableDump => 19
            case ConnectOut => 20
            case RegisterSlave => 21
            case StmtPrepare => 22
            case StmtExecute => 23
            case StmtSendLongData => 24
            case StmtClose => 25
            case StmtReset => 26
            case SetOption => 27
            case StmtFetch => 28
        }
    }

    public static func get(value: Byte): CommandType {
        match (value) {
            case 1 => Quit
            case 2 => InitDB
            case 3 => Query
            case 4 => FieldList
            case 5 => CreateDB
            case 6 => DropDB
            case 7 => Refresh
            case 8 => Shutdown
            case 9 => Statistics
            case 10 => ProcessInfo
            case 11 => Connect
            case 12 => ProcessKill
            case 13 => Debug
            case 14 => Ping
            case 15 => Time
            case 16 => DelayedInsert
            case 17 => ChangeUser
            case 18 => BinlogDump
            case 19 => TableDump
            case 20 => ConnectOut
            case 21 => RegisterSlave
            case 22 => StmtPrepare
            case 23 => StmtExecute
            case 24 => StmtSendLongData
            case 25 => StmtClose
            case 26 => StmtReset
            case 27 => SetOption
            case 28 => StmtFetch
            case _ => throw Exception("未识别的命令值类型: ${value}")
        }
    }
}
