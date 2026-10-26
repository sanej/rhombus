import XCTest
@testable import RhombusCore

final class ParserTests: XCTestCase {
    func testAddProduct() {
        XCTAssertEqual(VoiceParser.parse("Add product Orbit"), .addProduct(name: "orbit"))
        XCTAssertEqual(VoiceParser.parse("Create a new product called Moon Base."), .addProduct(name: "moon base"))
    }
    func testAddFeature() {
        XCTAssertEqual(VoiceParser.parse("Add feature dark launch to Orbit"),
                       .addFeature(title: "dark launch", product: "orbit", status: .idea))
        XCTAssertEqual(VoiceParser.parse("add feature search"),
                       .addFeature(title: "search", product: nil, status: .idea))
    }
    func testStatus() {
        XCTAssertEqual(VoiceParser.parse("Mark dark launch as done"), .setStatus(feature: "dark launch", status: .done))
        XCTAssertEqual(VoiceParser.parse("Set voice login to in progress"), .setStatus(feature: "voice login", status: .inProgress))
        XCTAssertEqual(VoiceParser.parse("Voice login is blocked"), .setStatus(feature: "voice login", status: .blocked))
    }
    func testDeleteAndUnknown() {
        XCTAssertEqual(VoiceParser.parse("delete product orbit"), .deleteProduct(name: "orbit"))
        XCTAssertEqual(VoiceParser.parse("delete feature search"), .deleteFeature(title: "search"))
        if case .unknown = VoiceParser.parse("hello there") {} else { XCTFail() }
    }
    func testMatcher() {
        let items = ["Dark Launch", "Voice Login"]
        XCTAssertEqual(Matcher.best("voice login", in: items, name: { $0 }), "Voice Login")
        XCTAssertEqual(Matcher.best("login", in: items, name: { $0 }), "Voice Login")
        XCTAssertNil(Matcher.best("payments", in: items, name: { $0 }))
    }
}
