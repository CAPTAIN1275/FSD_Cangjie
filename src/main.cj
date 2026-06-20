package FSD_Cangjie

main(): Int64 {
    println("==============================================")
    println("FSD v${VERSION}")
    println("Powered by HUAWEI Cangjie")
    println("==============================================")

    initLog("fsd.log")
    dolog(L_INFO, "FSD server starting...")

    let engine = FsdEngine("fsd.conf")
    fsdEngine = engine
    dolog(L_INFO, "Entering main loop on ports: client=${engine.clientPort}, server=${engine.serverPort}, system=${engine.systemPort}")

    while (true) {
        engine.run()
        sleep(10 * Duration.millisecond)
    }
    return 0
}
