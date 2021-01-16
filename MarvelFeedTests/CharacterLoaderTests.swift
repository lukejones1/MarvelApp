import Foundation

protocol HTTPClient {
    func get(_ url: URL, completion: @escaping  (HTTPURLResponse?, Error?) -> Void)
}

class CharacterLoader {
    
    private let url: URL
    private let client: HTTPClient
    
    enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (Error) -> Void) {
        client.get(url) { response, error in
            guard error == nil else {
                completion(.connectivity)
                return
            }
            guard response?.statusCode == 200 else {
                completion(.invalidData)
                return
            }
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
        client.complete(error: clientError)
        
        wait(for: [exp], timeout: 1.0)
        
        XCTAssertEqual(receivedErrors, [.connectivity])
    }
    
    func test_load_deliversInvalidDataErrorOnNon200Response() {
        let sampleCodes = [199, 201, 300, 400, 500]
        let (sut, client) = makeSUT()
        
        sampleCodes.enumerated().forEach { index, code in
            var receivedErrors: [CharacterLoader.Error] = []

            let exp = expectation(description: "Wait for load completion")

            sut.load() { error in
                receivedErrors.append(error)
                exp.fulfill()
            }
            
            client.complete(with: code, at: index)
            
            wait(for: [exp], timeout: 1.0)
            
            XCTAssertEqual(receivedErrors, [.invalidData])
        }
    }
    
    private func makeSUT(url: URL = URL(string: "www.any-url.com")!, file: StaticString = #file, line: UInt = #line) -> (sut: CharacterLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = CharacterLoader(url: url, client: client)
        return (sut, client)
    }
    
    class HTTPClientSpy: HTTPClient {
        var messages: [(url: URL, completion: (HTTPURLResponse?, Error?) -> Void)] = []
        
        var urls: [URL] {
            return messages.map { $0.url }
        }

        func get(_ url: URL, completion: @escaping (HTTPURLResponse?, Error?) -> Void) {
            messages.append((url, completion))
        }
        
        func complete(error: Error, at index: Int = 0) {
            messages[index].completion(nil, error)
        }
        
        func complete(with statusCode: Int, at index: Int = 0) {
            let response = HTTPURLResponse(
                url: urls[index],
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
            messages[index].completion(response, nil)
        }
    }
}
