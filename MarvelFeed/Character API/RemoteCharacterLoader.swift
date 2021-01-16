import Foundation


struct Root: Decodable {
    let data: Data

    struct Data: Decodable {
        let results: [RemoteCharacter]
        
        struct RemoteCharacter: Decodable {
            var id: Int
            var name: String
            var description: String?
            var thumbnail: Thumbnail?

            struct Thumbnail: Decodable {
                let path: URL
                let ext: String

                enum CodingKeys: String, CodingKey {
                    case path = "path"
                    case ext = "extension"
                }

                var standardMedium: URL {
                    path.appendingPathComponent("standard_medium").appendingPathExtension(ext)
                }
            }
        }
    }

    var characters: [Character] {
        data.results.map { Character(
            id: $0.id,
            name: $0.name,
            description: $0.description,
            imageURL: $0.thumbnail?.standardMedium
            )
        }
    }
}

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
                if response.statusCode == 409 {
                    completion(.failure(Error.invalidRequest))
                } else if response.statusCode == 200,
                    let root = try? JSONDecoder().decode(Root.self, from: data) {
                    completion(.success(root.characters))
                } else {
                    completion(.failure(Error.invalidData))
                }
            case .failure:
                completion(.failure(Error.connectivity))
            }
        }
    }
}
