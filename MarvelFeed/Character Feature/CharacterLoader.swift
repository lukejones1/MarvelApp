import Foundation

protocol CharacterLoader {
    typealias Result = Swift.Result<[Character], Error>
    func load(completion: @escaping (Result) -> Void)
}
