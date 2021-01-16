import Foundation

protocol HTTPClient {
    typealias Result = Swift.Result<(Data, HTTPURLResponse), Error>
    func get(_ url: URL, completion: @escaping  (Result) -> Void)
}
