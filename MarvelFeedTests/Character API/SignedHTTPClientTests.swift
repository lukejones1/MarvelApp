import Foundation
import CryptoKit

public let publicKey = "637070ffbd28fa31eaaaf0bd5cd5ded2"
public let privateKey = "69896d095beeaec10c97902652e077955478cc3f"

class SignedHTTPClientDecorator: HTTPClient {
    private let decoratee: HTTPClient
    private let hashTransformer: (String) -> String
    private let currentDate: Date
    
    init(decoratee: HTTPClient,
         hashTransformer: @escaping (String) -> String = MD5,
         currentDate: Date = Date()) {
        self.decoratee = decoratee
        self.hashTransformer = hashTransformer
        self.currentDate = currentDate
    }
    
    func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.queryItems = queryItems
        decoratee.get(from: components.url!) { _ in }
    }
    
    private var queryItems: [URLQueryItem] {
        let timestamp = String(Int(currentDate.timeIntervalSinceReferenceDate))
        let hash = hashTransformer(timestamp + privateKey + publicKey)
        
        return [
            URLQueryItem(name: "ts", value: timestamp),
            URLQueryItem(name: "apikey", value: publicKey),
            URLQueryItem(name: "hash", value: hash)
        ]
    }
}

private func MD5(string: String) -> String {
    let digest = Insecure.MD5.hash(data: string.data(using: .utf8) ?? Data())

    return digest.map {
        String(format: "%02hhx", $0)
    }.joined()
}


import XCTest
@testable import MarvelFeed

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
