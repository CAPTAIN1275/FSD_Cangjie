import std.fs.*

main(): Int64 {
    let configFiles = ["fsd.conf", "cert.txt", "motd.txt", "adminhelp.txt"]

    // unix
    let unixDir = Path("unix")
    if (!exists(unixDir)) { Directory.create(unixDir) }
    for (f in configFiles) {
        let src = Path(f); let dst = unixDir.join(f)
        if (exists(src)) { copy(src, to: dst, overwrite: true) }
    }
    let exe = Path("target/release/bin/main")
    if (exists(exe)) {
        copy(exe, to: unixDir.join("FSD_Cangjie"), overwrite: true)
    }

    // windows
    println("[FSD Build] Done!")
    return 0
}
