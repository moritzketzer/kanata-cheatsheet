import Testing


@Suite("Registry Browser")
struct RegistryBrowserTests {
    @Test("uncatalogued modifier-space slots are unrecorded, including legacy registries",
          arguments: ["unrecorded", "free"])
    func recognizesUnrecordedSlots(state: String) {
        let slot = ModifierSpaceSlot(
            modifiers: ["ctrl"], display: "Control + Space",
            state: state, bindingIds: []
        )

        #expect(slot.isUnrecorded)
    }

    @Test("recorded modifier-space slots retain their occupied state")
    func recognizesRecordedSlot() {
        let slot = ModifierSpaceSlot(
            modifiers: ["ctrl"], display: "Control + Space",
            state: "occupied", bindingIds: ["raycast.open"]
        )

        #expect(!slot.isUnrecorded)
    }

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
