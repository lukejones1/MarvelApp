import Foundation

protocol HTTPClient {
    func get(_ url: URL)
}

class CharacterLoader {
    
    private let url: URL
    private let client: HTTPClient
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load() {
        client.get(url)
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
        
        sut.load()

        XCTAssertEqual(client.urls, [url])
    }
    
    func test_loadTwice_sendsRequestWithCorrectURL() {
        let url = URL(string: "www.another-url.com")!
        let (sut, client) = makeSUT(url: url)
        
        sut.load()
        sut.load()

        XCTAssertEqual(client.urls, [url, url])
    }
    
    private func makeSUT(url: URL = URL(string: "www.any-url.com")!, file: StaticString = #file, line: UInt = #line) -> (sut: CharacterLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = CharacterLoader(url: url, client: client)
        return (sut, client)
    }
    
    class HTTPClientSpy: HTTPClient {
        var urls: [URL] = []

        func get(_ url: URL) {
            urls.append(url)
        }
    }
}
