import Foundation
import XCTest
@testable import MarvelFeed

class RemoteCharacterLoaderTests: XCTestCase {
    
    func test_init_doesNotSendRequest() {
        let (_, client) = makeSUT()
        
        XCTAssertEqual(client.urls, [])
    }
    
    func test_load_sendsRequestWithCorrectURL() {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }

        XCTAssertEqual(client.urls, [url])
    }
    
    func test_loadTwice_sendsRequestWithCorrectURL() {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url)
        
        sut.load() { _ in }
        sut.load() { _ in }

        XCTAssertEqual(client.urls, [url, url])
    }
    
    func test_load_deliversConnectivityErrorOnClientError() {
        let clientError = NSError(domain: "client", code: 0)
        let (sut, client) = makeSUT()
        
        expect(sut, toCompleteWith: .failure(RemoteCharacterLoader.Error.connectivity), when: {
            client.complete(with: clientError)
        })
        
    }
    
    func test_load_deliversInvalidDataErrorOnNon200Response() {
        let sampleCodes = [199, 201, 300, 400, 500]
        let (sut, client) = makeSUT()
        
        sampleCodes.enumerated().forEach { index, code in
            expect(sut, toCompleteWith: .failure(RemoteCharacterLoader.Error.invalidData), when: {
                client.complete(with: code, at: index)
            })
        }
    }
    
    func test_load_deliversInvalidRequestErrorOn409Response() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .failure(RemoteCharacterLoader.Error.invalidRequest), when: {
            client.complete(with: 409)
        })
    }
    
    func test_load_deliversInvalidDataErrorOnInvalidJSON() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .failure(RemoteCharacterLoader.Error.invalidData), when: {
            client.complete(data: Data("invalid json".utf8))
        })
    }
    
    func test_load_deliversSuccessOnValidJSON() {
        let (sut, client) = makeSUT()

        expect(sut, toCompleteWith: .success([]), when: {
            client.complete(data: makeItemsJSON([]))
        })
    }
    
    func test_load_deliversSuccessWithJSONItems() {
        let (sut, client) = makeSUT()
        
        let item1 = makeItem(
            id: 111,
            name: "a name",
            description: "a description",
            thumbnail: .init(path: URL(string: "www.path.com")!, ext: "png")
        )
        
        let item2 = makeItem(
            id: 123,
            name: "another name"
        )
        
        let json = makeItemsJSON([item2.json, item1.json])

        expect(sut, toCompleteWith: .success([item2.model, item1.model]), when: {
            client.complete(data: json)
        })
    }
    
    // MARK: Helpers
    
    private func makeSUT(url: URL = anyURL()) -> (sut: RemoteCharacterLoader, client: HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteCharacterLoader(url: url, client: client)
        return (sut, client)
    }
    
    private func expect(_ sut: RemoteCharacterLoader, toCompleteWith expectedResult: RemoteCharacterLoader.Result, when action: () -> Void, file: StaticString = #file, line: UInt = #line) {
        let exp = expectation(description: "Wait for load completion")
        
        sut.load { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedItems), .success(expectedItems)):
                XCTAssertEqual(receivedItems, expectedItems, file: file, line: line)
                
            case let (.failure(receivedError as RemoteCharacterLoader.Error), .failure(expectedError as RemoteCharacterLoader.Error)):
                XCTAssertEqual(receivedError, expectedError, file: file, line: line)
                
            default:
                XCTFail("Expected result \(expectedResult) got \(receivedResult) instead", file: file, line: line)
            }
            
            exp.fulfill()
        }
        
        action()
        
        wait(for: [exp], timeout: 1.0)
    }
    
    private func makeItem(id: Int, name: String, description: String? = nil, thumbnail: MarvelCharacterMapper.Root.Data.RemoteCharacter.Thumbnail? = nil) -> (model: Character, json: [String: Any]) {
        
        let item = Character(
            id: id,
            name: name,
            description: description,
            imageURL: thumbnail.flatMap { $0.path.appendingPathComponent("standard_medium").appendingPathExtension($0.ext)}
        )
        
        let thumbnailJson = thumbnail.flatMap { [
                "path": $0.path.absoluteString,
                "extension" : $0.ext
            ]
        }

        let json = [
            "id": id,
            "name": name,
            "description": description,
            "thumbnail": thumbnailJson
        ].mapValues { $0 }
        
        return (item, json)
    }
    
    private func makeItemsJSON(_ items: [[String: Any]]) -> Data {
        let data = ["results": items]
        let json = ["data": data]
        return try! JSONSerialization.data(withJSONObject: json)
    }
    
    class HTTPClientSpy: HTTPClient {
        var messages: [(url: URL, completion: (HTTPClient.Result) -> Void)] = []
        
        var urls: [URL] {
            return messages.map { $0.url }
        }

        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
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
