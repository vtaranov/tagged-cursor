import Testing
@testable import TaggedCursorCore

private let ru = LayoutInfo(id: "com.apple.keylayout.RussianWin", language: "ru")
private let en = LayoutInfo(id: "com.apple.keylayout.ABC", language: "en")

private func state() -> LayoutState {
    var s = LayoutState()
    s.enabled = [en, ru]
    s.setLocal(ru)
    return s
}

@Suite("Раскладка по языку")
struct LayoutInfoTests {
    @Test func флагиПоЯзыку() {
        #expect(ru.label == "🇷🇺")
        #expect(en.label == "🇺🇸")
        #expect(LayoutInfo(id: "com.apple.keylayout.British", language: "en").label == "🇬🇧")
        #expect(LayoutInfo(id: "x", language: "pl").label == "PL")
    }

    @Test func письменность() {
        #expect(ru.script == .cyrillic)
        #expect(en.script == .latin)
        #expect(LayoutInfo(id: "x", language: "uk").script == .cyrillic)
        #expect(LayoutInfo(id: "com.apple.CharacterPaletteIM", language: "").script == .other)
    }

    @Test func письменностьТекста() {
        #expect(script(of: "abc") == .latin)
        #expect(script(of: "абв") == .cyrillic)
        #expect(script(of: " 123,") == .other)
        // Решает первая буква, а не знаки препинания перед ней.
        #expect(script(of: "«ф") == .cyrillic)
    }
}

@Suite("Состояние раскладки")
struct LayoutStateTests {
    @Test func локальнаяРаскладка() {
        var s = state()
        #expect(s.label == "🇷🇺")
        s.setLocal(en)
        #expect(s.label == "🇺🇸")
    }

    @Test func удалённыйCapsLockПереключаетПоКругу() {
        var s = state()
        s.cycleRemote()
        #expect(s.label == "🇺🇸")
        #expect(s.remote == "🇺🇸")
        s.cycleRemote()
        #expect(s.label == "🇷🇺")
        // Вернулись к локальной — коррекция больше не нужна.
        #expect(s.remote == nil)
    }

    @Test func однаРаскладкаНеПереключается() {
        var s = LayoutState()
        s.enabled = [ru]
        s.setLocal(ru)
        s.cycleRemote()
        #expect(s.label == "🇷🇺")
    }

    @Test func набраннаяБукваИсправляетФлаг() {
        var s = state()
        s.typed(.latin)
        #expect(s.label == "🇺🇸")
        s.typed(.cyrillic)
        #expect(s.label == "🇷🇺")
        #expect(s.remote == nil)
    }

    @Test func цифрыИЗнакиНеМеняютФлаг() {
        var s = state()
        s.cycleRemote()
        s.typed(.other)
        #expect(s.label == "🇺🇸")
    }

    @Test func сменаЛокальнойРаскладкиОтменяетКоррекцию() {
        var s = state()
        s.cycleRemote()
        #expect(s.remote == "🇺🇸")
        s.setLocal(en)
        #expect(s.remote == nil)
        #expect(s.label == "🇺🇸")
    }

    @Test func повторныйОпросЛокальнойНеСбрасываетКоррекцию() {
        var s = state()
        s.cycleRemote()
        s.setLocal(ru)
        #expect(s.label == "🇺🇸")
    }
}
