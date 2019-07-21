import Foundation
import Combine

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

public protocol APIResource {
    
    var method: HTTPMethod { get }
    var endpoint: String { get }
    var base: String { get }
    var parameters: [String: String]? { get }
    
    func buildURL() throws -> URL
    
}

public enum APIError: Error {
    case invalidUrl
    case encodingFailed
    case networkFailed
    case missingBody
    case decodingFailed
}

public extension APIResource {
    
    func buildURL() throws -> URL {
        guard var resourcerUrlComponents = URLComponents(string: base) else {
            throw APIError.invalidUrl
        }
        if let parameters = parameters {
            var urlParams: [URLQueryItem] = []
            parameters.forEach { (param) in
                urlParams.append(URLQueryItem(name: param.key, value: param.value))
            }
            resourcerUrlComponents.queryItems = urlParams
        }
        guard let resourceUrl = resourcerUrlComponents.url else {
            throw APIError.invalidUrl
        }
        return resourceUrl
    }
    
}

public struct EmptyBody: Codable {
    public init() {
        
    }
}

enum Test: APIResource {
    var method: HTTPMethod {
        return .GET
    }
    
    var endpoint: String {
        return "/test"
    }
    
    var base: String {
        return "www.google.com"
    }
    
    var parameters: [String : String]? {
        return nil
    }
    
    case test
    
    
    
}


@available(iOS 13.0, *)
public protocol Requestable {
    
    static func buildURLRequest<T: Encodable>(endpoint: APIResource, body: T) throws -> URLRequest
//    static func getResource<RequestType: Encodable, ResponseType>(from: APIResource, with requestBody: RequestType, get responseBody: ResponseType.Type) -> Publishers.Future<ResponseType, APIError> where ResponseType: Decodable
    static func getResource<RequestType: Encodable, ResponseType>(from: APIResource, with requestBody: RequestType?, get responseBody: ResponseType.Type) -> Future<ResponseType, APIError> where ResponseType: Decodable
}

@available(iOS 13.0, *)
public extension Requestable {
    
    static func buildURLRequest<T: Encodable>(endpoint: APIResource, body: T) throws -> URLRequest {
        let resourceUrl = try endpoint.buildURL()
        var resourceRequest = URLRequest(url: resourceUrl)
        resourceRequest.httpMethod = endpoint.method.rawValue
        let encoder = JSONEncoder()
        guard let body = try? encoder.encode(body) else {
            throw APIError.encodingFailed
        }
        resourceRequest.httpBody = body
        return resourceRequest
    }
    
    static func getResource<RequestType: Encodable, ResponseType>(from endpoint: APIResource, with requestBody: RequestType? = nil, get responseBody: ResponseType.Type) -> Future<ResponseType, APIError> where ResponseType: Decodable {
        return Future { (completion) in
            do {
                let request = try self.buildURLRequest(endpoint: endpoint, body: requestBody)
                let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                    if error != nil {
                        return completion(.failure(.networkFailed))
                    }
                    var body: Data?
                    if let data = data {
                        body = data
                    } else {
                        body = Data()
                    }
                    guard let serverData = body else {
                        return completion(.failure(.missingBody))
                    }
                    let decoder = JSONDecoder()
                    guard let resource = try? decoder.decode(ResponseType.self, from: serverData) else {
                        return completion(.failure(.decodingFailed))
                    }
                    completion(.success(resource))
                }
                task.resume()
            } catch let error as APIError {
                return completion(.failure(error))
            } catch {
                return completion(.failure(.networkFailed))
            }
        }
    }
    
}

public struct APIRequest: Requestable { }
