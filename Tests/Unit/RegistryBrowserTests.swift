import Testing


@Suite("Registry Browser")
struct RegistryBrowserTests {
    @Test("registry-open routes to browser")
    func routesRegistryOpen() {
        #expect(AppMessageRouter.route("registry-open") == .openRegistry)
        #expect(
            AppMessageRouter.route("cheatsheet-space-toggle-free")
                == .overlay("cheatsheet-space-toggle-free")
        )
    }

    @Test("repeated open reuses existing window")
    func reusesWindow() {
        var logic = BrowserWindowLogic()
        #expect(logic.open() == .create)
        #expect(logic.open() == .raiseExisting)
        logic.closed()
        #expect(logic.open() == .create)
    }

    @Test("unrelated messages stay on overlay route")
    func unrelatedMessagesUseOverlay() {
        #expect(AppMessageRouter.route("cheatsheet-hide") == .overlay("cheatsheet-hide"))
        #expect(AppMessageRouter.route("unknown") == .overlay("unknown"))
    }
}
