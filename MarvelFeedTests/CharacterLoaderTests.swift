import Foundation

protocol HTTPClient {
    func get(_ url: URL, completion: @escaping  (Error) -> Void)
}

class CharacterLoader {
    
    private let url: URL
    private let client: HTTPClient
    
    enum Error: Swift.Error {
        case connectivity
    }
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (Error) -> Void) {
        client.get(url) { error in
            completion(.connectivity)
        }
    }
}

import XCTest

class CharacterLoaderTests: XCTestCase {
    
    func test_init_doesNotSendRequest() {
        let (_, client) = makeSUT()
        
        XCTAssertEqual(client.urls, [])
    }
    
    func test_load_sendsRequestWithCorrectURL() {
        let url = URL(string: "www.another-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }

        XCTAssertEqual(client.urls, [url])
    }
    
    func test_loadTwice_sendsRequestWithCorrectURL() {
        let url = URL(string: "www.another-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }
        sut.load() { _ in }

        XCTAssertEqual(client.urls, [url, url])
    }
    
    func test_load_deliversConnectivityErrorOnClientError() {
        let clientError = NSError(domain: "client", code: 0)
        let (sut, client) = makeSUT()
        
        let exp = expectation(description: "Wait for load completion")
        var receivedErrors: [CharacterLoader.Error] = []
        sut.load() { error in
            receivedErrors.append(error)
            exp.fulfill()
        }
        client.complete(with: clientError)
        
        wait(for: [exp], timeout: 1.0)
        
        XCTAssertEqual(receivedErrors, [.connectivity])
    }
    
    private func makeSUT(url: URL = URL(string: "www.any-url.com")!, file: StaticString = #file, line: UInt = #line) -> (sut: CharacterLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = CharacterLoader(url: url, client: client)
        return (sut, client)
    }
    
    class HTTPClientSpy: HTTPClient {
        var messages: [(url: URL, completion: (Error) -> Void)] = []
        
        var urls: [URL] {
            return messages.map { $0.url }
        }

        func get(_ url: URL, completion: @escaping  (Error) -> Void) {
            messages.append((url, completion))
        }
        
        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(error)
        }
    }
}
