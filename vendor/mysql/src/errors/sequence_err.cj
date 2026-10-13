package mysql.errors

import std.database.sql.SqlException

public class SequenceException <: SqlException {
    public init(message: String) {
        super(message)
    }
}