import Testing


@Suite("Yabai modifier snapshots")
struct YabaiModifierTests {
    @Test("only left output bits select Yabai actions")
    func onlyLeftOutputsSelectYabaiActions() {
        #expect(YabaiModifier.active(in: 0x2b) == Set(YabaiModifier.allCases))
        #expect(YabaiModifier.active(in: 0x2054).isEmpty)
        #expect(YabaiModifier.active(in: 0x2021) == [.control, .option])
    }

    @Test("all left combinations ignore every right output combination")
    func everyLeftAndRightCombination() {
        let modifiers = YabaiModifier.allCases
        let rightMasks: [UInt] = [0x2000, 0x40, 0x10, 0x4]

        for leftCombination in 0..<16 {
            let expected = Set(modifiers.enumerated().compactMap { index, modifier in
                leftCombination & (1 << index) == 0 ? nil : modifier
            })
            let leftFlags = expected.reduce(UInt(0)) { $0 | $1.outputMask }

            for rightCombination in 0..<16 {
                let rightFlags = rightMasks.enumerated().reduce(UInt(0)) { flags, entry in
                    rightCombination & (1 << entry.offset) == 0
                        ? flags
                        : flags | entry.element
                }
                #expect(
                    YabaiModifier.active(in: leftFlags | rightFlags) == expected,
                    "left=\(leftCombination) right=\(rightCombination)"
                )
            }
        }
    }
}
