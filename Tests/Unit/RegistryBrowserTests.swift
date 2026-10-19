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

    @Test("no search leaves every modifier-space binding at full opacity")
    func emptySearchDimsNothing() {
        #expect(
            !ModifierSpaceDimming.isDimmed(
                bindingID: "raycast.open", search: "",
                matchingBindingIDs: ["raycast.open", "yabai.focus"]
            )
        )
        #expect(
            !ModifierSpaceDimming.isDimmed(
                bindingID: "raycast.open", search: "   ",
                matchingBindingIDs: ["yabai.focus"]
            )
        )
    }

    @Test("an active search dims only the bindings it does not match")
    func activeSearchDimsMissesOnly() {
        let matches: Set<String> = ["raycast.open"]

        #expect(
            !ModifierSpaceDimming.isDimmed(
                bindingID: "raycast.open", search: "raycast", matchingBindingIDs: matches
            )
        )
        #expect(
            ModifierSpaceDimming.isDimmed(
                bindingID: "yabai.focus", search: "raycast", matchingBindingIDs: matches
            )
        )
    }

    @Test("a search that matches nothing dims every modifier-space binding")
    func zeroMatchSearchDimsEverything() {
        #expect(
            ModifierSpaceDimming.isDimmed(
                bindingID: "raycast.open", search: "nomatch", matchingBindingIDs: []
            )
        )
        #expect(
            ModifierSpaceDimming.isDimmed(
                bindingID: "yabai.focus", search: "nomatch", matchingBindingIDs: []
            )
        )
    }

    @Test("unrelated messages stay on overlay route")
    func unrelatedMessagesUseOverlay() {
        #expect(AppMessageRouter.route("cheatsheet-hide") == .overlay("cheatsheet-hide"))
        #expect(AppMessageRouter.route("unknown") == .overlay("unknown"))
    }
}
