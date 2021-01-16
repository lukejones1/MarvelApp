import Foundation

class RemoteCharacterLoader: CharacterLoader {

    private let url: URL
    private let client: HTTPClient

    enum Error: Swift.Error {
        case connectivity
        case invalidData
        case invalidRequest
    }

    init(url: URL, client: HTTPClient) {
        self.url = url
        self.client = client
    }

    func load(completion: @escaping (CharacterLoader.Result) -> Void) {
        client.get(url) { result in
            switch result {
            case let .success((data, response)):
                do {
                    let characters = try MarvelCharacterMapper.map(response, data)
                    completion(.success(characters))
                } catch {
                    completion(.failure(error))
                }
            case .failure:
                completion(.failure(Error.connectivity))
            }
        }
    }
}
