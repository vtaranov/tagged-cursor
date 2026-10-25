import Foundation
import Testing
@testable import TaggedCursorCore

@Suite("Показ и скрытие флага")
struct DisplayStateTests {
    @Test func клавишиНабора() {
        #expect(DisplayState.isTypingKey(code: 0, hasCommandOrControl: false))
        // Cmd+A, стрелка влево, Esc.
        #expect(!DisplayState.isTypingKey(code: 0, hasCommandOrControl: true))
        #expect(!DisplayState.isTypingKey(code: 123, hasCommandOrControl: false))
        #expect(!DisplayState.isTypingKey(code: 53, hasCommandOrControl: false))
    }

    @Test func паузаВозвращаетФлаг() {
        let start = Date()
        var d = DisplayState()
        d.keyDown(at: start)
        let early = d.shouldShow(now: start.addingTimeInterval(1.9), pauseMs: 2000)
        let late = d.shouldShow(now: start.addingTimeInterval(2.0), pauseMs: 2000)
        #expect(!early)
        #expect(late)
    }

    @Test func нулеваяПаузаОставляетФлагСкрытым() {
        let start = Date()
        var d = DisplayState()
        d.keyDown(at: start)
        let hidden = d.shouldShow(now: start.addingTimeInterval(3600), pauseMs: 0)
        #expect(!hidden)
        d.contextChanged()
        let shown = d.shouldShow(now: start, pauseMs: 0)
        #expect(shown)
    }

    @Test func сменаКонтекстаПоказываетСразу() {
        var d = DisplayState()
        d.keyDown(at: Date())
        d.contextChanged()
        let shown = d.shouldShow(now: Date(), pauseMs: 2000)
        #expect(shown)
    }
}
