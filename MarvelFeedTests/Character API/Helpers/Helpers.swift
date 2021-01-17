import XCTest

extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}

func anyURL() -> URL {
    URL(string: "http://any-url.com")!
}

func anyError() -> NSError {
    NSError(domain: "any error", code: 0)
}

func anyData() -> Data {
    Data("any data".utf8)
}

func anyHTTPURLResponse() -> HTTPURLResponse {
    HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
}
