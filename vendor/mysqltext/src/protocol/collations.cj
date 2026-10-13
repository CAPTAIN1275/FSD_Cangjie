package mysql.protocol

import std.collection.*

// https://dev.mysql.com/doc/refman/5.7/en/charset-connection.html#charset-connection-impermissible-client-charset
// 映射编码
var collations = HashMap<String, Int>(
    [("koi8u_general_ci", 22), ("cp1250_polish_ci", 99), ("utf8_vietnamese_ci", 215), ("utf8mb4_esperanto_ci", 241),
    ("gb18030_bin", 249), ("hp8_english_ci", 6), ("cp1250_croatian_ci", 44), ("greek_bin", 70), ("utf8_unicode_ci", 192),
    ("utf8mb4_polish_ci", 229), ("cp1257_lithuanian_ci", 29), ("euckr_korean_ci", 19), ("macce_general_ci", 38),
    ("utf8_lithuanian_ci", 204), ("utf8mb4_persian_ci", 240), ("latin2_general_ci", 9), ("latin1_swedish_ci", 8),
    ("cp852_general_ci", 40), ("utf8mb4_bin", 46), ("macroman_bin", 53), ("cp1256_general_ci", 57),
    ("utf8_slovenian_ci", 196), ("utf8_spanish_ci", 199), ("dec8_swedish_ci", 3), ("utf8mb4_german2_ci", 244),
    ("utf8mb4_icelandic_ci", 225), ("sjis_japanese_ci", 13), ("latin5_turkish_ci", 30), ("latin1_bin", 47),
    ("latin1_general_cs", 49), ("cp852_bin", 81), ("tis620_bin", 89), ("utf8_slovak_ci", 205), ("latin2_czech_cs", 2),
    ("utf8mb4_spanish2_ci", 238), ("tis620_thai_ci", 18), ("keybcs2_bin", 73), ("koi8u_bin", 75), ("gbk_bin", 87),
    ("hebrew_general_ci", 16), ("latin1_german2_ci", 31), ("cp1251_general_ci", 51), ("cp1257_bin", 58),
    ("utf8mb4_croatian_ci", 245), ("ujis_japanese_ci", 12), ("cp866_bin", 68), ("latin5_bin", 78),
    ("utf8mb4_danish_ci", 235), ("latin7_general_cs", 42), ("utf8_tolower_ci", 76), ("utf8mb4_general_ci", 45),
    ("cp932_bin", 96), ("utf8mb4_unicode_ci", 224), ("cp1250_czech_cs", 34), ("utf8_swedish_ci", 200),
    ("utf8_general_mysql500_ci", 223), ("utf8mb4_roman_ci", 239), ("utf8mb4_sinhala_ci", 243), ("utf8_estonian_ci", 198),
    ("keybcs2_general_ci", 37), ("big5_bin", 84), ("utf8mb4_slovak_ci", 237), ("latin2_hungarian_ci", 21),
    ("utf8_czech_ci", 202), ("utf8_german2_ci", 212), ("utf8mb4_unicode_520_ci", 246), ("euckr_bin", 85),
    ("swe7_swedish_ci", 10), ("koi8r_general_ci", 7), ("cp1251_bulgarian_ci", 14), ("sjis_bin", 88), ("geostd8_bin", 93),
    ("macroman_general_ci", 39), ("latin1_danish_ci", 15), ("greek_general_ci", 25), ("latin2_bin", 77),
    ("utf8_danish_ci", 203), ("utf8mb4_estonian_ci", 230), ("big5_chinese_ci", 1), ("cp1256_bin", 67),
    ("cp932_japanese_ci", 95), ("eucjpms_japanese_ci", 97), ("utf8_icelandic_ci", 193), ("utf8_latvian_ci", 194),
    ("utf8_persian_ci", 208), ("utf8mb4_slovenian_ci", 228), ("cp1250_general_ci", 26), ("utf8mb4_vietnamese_ci", 247),
    ("dec8_bin", 69), ("hebrew_bin", 71), ("utf8_bin", 83), ("eucjpms_bin", 98), ("gb2312_chinese_ci", 24),
    ("ascii_bin", 65), ("utf8_sinhala_ci", 211), ("cp1257_general_ci", 59), ("utf8_unicode_520_ci", 214),
    ("gb18030_unicode_520_ci", 250), ("latin7_general_ci", 41), ("cp866_general_ci", 36), ("macce_bin", 43),
    ("armscii8_bin", 64), ("cp1250_bin", 66), ("latin7_bin", 79), ("ujis_bin", 91), ("utf8mb4_swedish_ci", 232),
    ("armscii8_general_ci", 32), ("utf8_croatian_ci", 213), ("utf8mb4_spanish_ci", 231), ("latin7_estonian_cs", 20),
    ("cp1251_bin", 50), ("utf8mb4_lithuanian_ci", 236), ("latin1_german1_ci", 5), ("swe7_bin", 82),
    ("utf8mb4_romanian_ci", 227), ("utf8mb4_hungarian_ci", 242), ("koi8r_bin", 74), ("binary", 63), ("cp850_bin", 80),
    ("utf8_spanish2_ci", 206), ("utf8_esperanto_ci", 209), ("utf8mb4_turkish_ci", 233), ("latin1_general_ci", 48),
    ("utf8_general_ci", 33), ("cp1251_ukrainian_ci", 23), ("ascii_general_ci", 11), ("gb2312_bin", 86),
    ("cp850_general_ci", 4), ("utf8_turkish_ci", 201), ("utf8_hungarian_ci", 210), ("utf8mb4_latvian_ci", 226),
    ("utf8mb4_czech_ci", 234), ("gb18030_chinese_ci", 248), ("utf8mb4_0900_ai_ci", 255), ("latin1_spanish_ci", 94),
    ("cp1251_general_cs", 52), ("hp8_bin", 72), ("geostd8_general_ci", 92), ("utf8_romanian_ci", 195),
    ("latin2_croatian_ci", 27), ("utf8_polish_ci", 197), ("utf8_roman_ci", 207), ("gbk_chinese_ci", 28)])
