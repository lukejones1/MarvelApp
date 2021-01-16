import Foundation

protocol HTTPClient {
    typealias Result = Swift.Result<(Data, HTTPURLResponse), Error>
    func get(_ url: URL, completion: @escaping  (Result) -> Void)
}

struct Root: Decodable {
    
}

public struct Character: Equatable {
    public var id: Int
    public var name: String
    public var description: String?
    public var imageURL: URL?
}

class CharacterLoader {
    
    private let url: URL
    private let client: HTTPClient
    
    enum Error: Swift.Error {
        case connectivity
        case invalidData
        case invalidRequest
    }
    
    public typealias Result = Swift.Result<[Character], Error>

    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }
    
    func load(completion: @escaping (Result) -> Void) {
        client.get(url) { result in
            switch result {
            case let .success((data, response)):
                if response.statusCode == 409 {
                    completion(.failure(.invalidRequest))
                } else if response.statusCode == 200,
                    let _ = try? JSONDecoder().decode(Root.self, from: data) {
                    completion(.success([]))
                } else {
                    completion(.failure(.invalidData))
                }
            case .failure:
                completion(.failure(.connectivity))
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
        
        expect(sut, toCompleteWith: .failure(.connectivity), when: {
            client.complete(with: clientError)
        })
        
    }
    
    func test_load_deliversInvalidDataErrorOnNon200Response() {
        let sampleCodes = [199, 201, 300, 400, 500]
        let (sut, client) = makeSUT()
        
        sampleCodes.enumerated().forEach { index, code in
            expect(sut, toCompleteWith: .failure(.invalidData), when: {
                client.complete(with: code, at: index)
            })
        }
    }
    
    func test_load_deliversInvalidRequestErrorOn409Response() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .failure(.invalidRequest), when: {
            client.complete(with: 409)
        })
    }
    
    func test_load_deliversInvalidDataErrorOnInvalidJSON() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .failure(.invalidData), when: {
            client.complete(data: Data("invalid json".utf8))
        })
    }
    
    func test_load_deliversSuccessOnValidJSON() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .success([]), when: {
            client.complete(data: Data("{\"data\": []}".utf8))
        })
    }
    
    // MARK: Helpers
    
    private func makeSUT(url: URL = URL(string: "www.any-url.com")!) -> (sut: CharacterLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = CharacterLoader(url: url, client: client)
        return (sut, client)
    }
    
    private func expect(_ sut: CharacterLoader, toCompleteWith result: CharacterLoader.Result, when action: () -> Void, file: StaticString = #file, line: UInt = #line) {
        let exp = expectation(description: "Wait for load completion")
        var receivedResult: CharacterLoader.Result?
        sut.load() { result in
            receivedResult = result
            exp.fulfill()
        }
        
        action()
        wait(for: [exp], timeout: 1.0)
        
        XCTAssertEqual(receivedResult, result, file: file, line: line)
    }
    
    class HTTPClientSpy: HTTPClient {
        var messages: [(url: URL, completion: (HTTPClient.Result) -> Void)] = []
        
        var urls: [URL] {
            return messages.map { $0.url }
        }

        func get(_ url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
            messages.append((url, completion))
        }
        
        func complete(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func complete(with statusCode: Int = 200, data: Data = Data(), at index: Int = 0) {
            let response = HTTPURLResponse(
                url: urls[index],
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            messages[index].completion(.success((data, response)))
        }
    }
}
