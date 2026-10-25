import CoreGraphics
import Testing
@testable import TaggedCursorCore

private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)

@Suite("Геометрия")
struct GeometryTests {
    @Test func переводКоординат() {
        let r = Geometry.cocoaRect(fromAX: CGRect(x: 100, y: 33, width: 2, height: 20), mainScreenHeight: 956)
        #expect(r == CGRect(x: 100, y: 903, width: 2, height: 20))
    }

    @Test func отбраковкаНекорректныхПрямоугольников() {
        func check(_ r: CGRect) -> CGRect? {
            Geometry.validCaret(r, mainScreenHeight: 956, screens: [screen])
        }
        #expect(check(CGRect(x: 100, y: 100, width: 0, height: 18)) != nil)
        // Нулевые координаты, слишком низкий и слишком высокий курсор, вне экранов.
        #expect(check(CGRect(x: 0, y: 0, width: 0, height: 18)) == nil)
        #expect(check(CGRect(x: 100, y: 100, width: 0, height: 2)) == nil)
        #expect(check(CGRect(x: 100, y: 100, width: 0, height: 500)) == nil)
        #expect(check(CGRect(x: -3000, y: 100, width: 0, height: 18)) == nil)
    }

    @Test func схлопываниеПустогоПоля() {
        let wide = Geometry.collapsed(CGRect(x: 50, y: 10, width: 500, height: 20))
        #expect(wide == CGRect(x: 50, y: 10, width: 0, height: 20))
        let caret = CGRect(x: 50, y: 10, width: 2, height: 20)
        #expect(Geometry.collapsed(caret) == caret)
    }

    @Test func рамкаПоляВместоКурсора() {
        let field = CGRect(x: 215, y: 205, width: 1173, height: 19)
        #expect(Geometry.looksLikeFieldFrame(field, axFrame: field))
        #expect(!Geometry.looksLikeFieldFrame(CGRect(x: 300, y: 205, width: 0, height: 19), axFrame: field))
        #expect(!Geometry.looksLikeFieldFrame(field, axFrame: nil))
    }

    @Test func флагНадКурсором() {
        let anchor = Anchor(rect: CGRect(x: 500, y: 400, width: 0, height: 20), source: .range)
        let origin = Geometry.flagOrigin(anchor: anchor, flagSize: CGSize(width: 20, height: 18),
                                         gap: 2, screenMaxY: 956)
        #expect(origin == CGPoint(x: 490, y: 422))
    }

    @Test func уВерхнегоКраяЭкранаФлагПодКурсором() {
        let anchor = Anchor(rect: CGRect(x: 500, y: 930, width: 0, height: 20), source: .range)
        let origin = Geometry.flagOrigin(anchor: anchor, flagSize: CGSize(width: 20, height: 18),
                                         gap: 2, screenMaxY: 956)
        #expect(origin.y == 910)
    }

    @Test func полеБезПозицииКурсораФлагСлева() {
        let anchor = Anchor(rect: CGRect(x: 500, y: 400, width: 300, height: 20), source: .field)
        let origin = Geometry.flagOrigin(anchor: anchor, flagSize: CGSize(width: 20, height: 18),
                                         gap: 2, screenMaxY: 956)
        #expect(origin == CGPoint(x: 478, y: 401))
    }
}
