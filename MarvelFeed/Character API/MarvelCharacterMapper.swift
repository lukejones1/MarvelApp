import Foundation

class MarvelCharacterMapper {
    
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
    
    static func map(_ response: HTTPURLResponse, _ data: Data) throws -> [Character] {
        if response.statusCode == 409 {
            throw RemoteCharacterLoader.Error.invalidRequest
        }
        guard response.statusCode == 200,
            let root = try? JSONDecoder().decode(Root.self, from: data) else {
            throw RemoteCharacterLoader.Error.invalidData
        }

        return root.characters
    }
}
