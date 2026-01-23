import XCTest

/// Tests for URL parsing logic used throughout the app
final class URLParsingTests: XCTestCase {

    // Helper function that mirrors the app's URL fixing logic
    private func fixURL(_ input: String) -> URL? {
        if input.lowercased().hasPrefix("http") {
            return URL(string: input)
        } else if input.contains(".") && !input.contains(" ") {
            return URL(string: "https://" + input)
        } else {
            let query = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            return URL(string: "https://www.google.com/search?q=" + query)
        }
    }

    // MARK: - HTTP/HTTPS URL Tests

    func testHttpsURL() {
        let url = fixURL("https://example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "https://example.com")
    }

    func testHttpURL() {
        let url = fixURL("http://example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.absoluteString, "http://example.com")
    }

    func testURLWithPath() {
        let url = fixURL("https://example.com/path/to/page")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.path, "/path/to/page")
    }

    func testURLWithQueryParams() {
        let url = fixURL("https://example.com/search?q=test&page=1")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("q=test") ?? false)
    }

    // MARK: - Domain Auto-completion Tests

    func testDomainWithoutProtocol() {
        let url = fixURL("example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "https")
        XCTAssertEqual(url?.host, "example.com")
    }

    func testDomainWithSubdomain() {
        let url = fixURL("www.example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.example.com")
    }

    func testDomainWithPath() {
        let url = fixURL("github.com/user/repo")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "github.com")
        XCTAssertEqual(url?.path, "/user/repo")
    }

    func testIPAddress() {
        let url = fixURL("192.168.1.1")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "192.168.1.1")
    }

    func testLocalhost() {
        let url = fixURL("localhost:3000")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("localhost") ?? false)
    }

    // MARK: - Search Query Tests

    func testSearchQuery() {
        let url = fixURL("how to cook pasta")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
        XCTAssertEqual(url?.path, "/search")
        XCTAssertTrue(url?.query?.contains("how%20to%20cook%20pasta") ?? false)
    }

    func testSearchQueryWithSpecialCharacters() {
        let url = fixURL("what is 2+2?")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
    }

    func testSingleWord() {
        // Single word without dot should be treated as search
        let url = fixURL("weather")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
    }

    func testMultipleWords() {
        let url = fixURL("swift programming tutorial")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
        XCTAssertTrue(url?.absoluteString.contains("swift") ?? false)
    }

    // MARK: - Edge Cases

    func testEmptyInput() {
        // Empty string still creates a search URL
        let url = fixURL("")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
    }

    func testWhitespaceOnly() {
        let url = fixURL("   ")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
    }

    func testMixedCaseProtocol() {
        let url = fixURL("HTTPS://Example.com")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "HTTPS")
    }

    func testDotInSearchQuery() {
        // "node.js tutorial" has a dot but also has space, so should be search
        let url = fixURL("node.js tutorial")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "www.google.com")
    }

    func testFileExtension() {
        // ".com" alone with dot but no space should try as domain
        let url = fixURL("test.js")
        XCTAssertNotNil(url)
        // This gets https:// prepended
        XCTAssertEqual(url?.scheme, "https")
    }

    // MARK: - URL Encoding Tests

    func testSpaceEncoding() {
        let url = fixURL("hello world")
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("%20") ?? false)
    }

    func testUnicodeCharacters() {
        let url = fixURL("cafe test")
        XCTAssertNotNil(url)
        // Should properly encode
        XCTAssertNotNil(url?.absoluteString)
    }

    func testAmpersandInSearch() {
        let url = fixURL("tom & jerry")
        XCTAssertNotNil(url)
        // URL should be valid Google search
        XCTAssertEqual(url?.host, "www.google.com")
        XCTAssertTrue(url?.absoluteString.contains("tom") ?? false)
    }
}
