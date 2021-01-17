import Foundation
@testable import MarvelFeed
import XCTest

class SignedHTTPClientDecoratorTest: XCTestCase {
    
    func test_get_sendsRequestWithURLToDecorateeWithCorrectQuery() {
        let url = anyURL()
        let hashString = "hash_string"
        let currentDate = Date()
        let (sut, decoratee) = makeSUT(
            hashTransformer: { _ in hashString },
            date: currentDate
        )
        
        sut.get(from: url) { _ in }

        let timeStamp = Int(currentDate.timeIntervalSinceReferenceDate)
        let queryString = "ts=\(timeStamp)&apikey=\(publicKey)&hash=\(hashString)"
        let expectedURL = URL(string: url.absoluteString + "?" + queryString)
        XCTAssertEqual(decoratee.urls, [expectedURL])
    }
    
    func test_get_deliversResultToDecoratee() {
        let (sut, decoratee) = makeSUT()
        let expectedResult: HTTPClient.Result = .success((anyData(), anyHTTPURLResponse()))
        
        let exp = expectation(description: "wait for completion")
        sut.get(from: anyURL()) { retrievedResult in
            switch (retrievedResult, expectedResult) {
            case let (.success(retrievedResult), .success(expectedResult)):
                XCTAssertEqual(retrievedResult.0, expectedResult.0)
                XCTAssertEqual(retrievedResult.1, expectedResult.1)
            default:
                XCTFail("Expected result \(expectedResult) got \(retrievedResult) instead")
            }
            exp.fulfill()
        }
        decoratee.complete(with: expectedResult)

        wait(for: [exp], timeout: 0.1)
    }
    
    private func makeSUT(hashTransformer: @escaping (String) -> String = { _ in "any" } , date: Date = Date(), file: StaticString = #file, line: UInt = #line) -> (SignedHTTPClientDecorator, SpyHTTPClient)  {
        let decorateeClient = SpyHTTPClient()
        let sut = SignedHTTPClientDecorator(decoratee: decorateeClient, hashTransformer: hashTransformer, currentDate: date)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, decorateeClient)
    }
    
    class SpyHTTPClient: HTTPClient {
        
        var messages: [(url: URL, completion: (HTTPClient.Result) -> Void)] = []
        
        var urls: [URL] {
            return messages.map { $0.url }
        }
        
        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
            messages.append((url, completion))
        }
        
        func complete(with result: HTTPClient.Result, at index: Int = 0) {
            messages[index].completion(result)
        }
    }
}
