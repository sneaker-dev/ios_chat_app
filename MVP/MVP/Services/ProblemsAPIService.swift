import Foundation

enum ProblemsAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidURL
    case noData
    case invalidResponse
    case serverError(Int, String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:         return "Not logged in or session expired. Please log in again."
        case .invalidURL:               return "Invalid request URL."
        case .noData:                   return "No response from server."
        case .invalidResponse:          return "Invalid response from server."
        case .serverError(_, let msg):  return msg.isEmpty ? "Server error." : msg
        case .decodingFailed(let msg):  return "Could not read response: \(msg)"
        }
    }
}

final class ProblemsAPIService {
    static let shared = ProblemsAPIService()
    private let session = URLSession.shared

    private init() {}

    func getCatalog() async throws -> ProblemCatalogResponse {
        try await get(path: "/api/v1/problems/catalog", requiresAuth: true)
    }

    func getActiveProblems() async throws -> DeviceProblemsResponse {
        try await get(path: "/api/v1/problems/active", requiresAuth: true)
    }

    func enableProblem(key: String) async throws -> ProblemToggleResponse {
        try await put(path: "/api/v1/problems/\(key)/enable")
    }

    func disableProblem(key: String) async throws -> ProblemToggleResponse {
        try await put(path: "/api/v1/problems/\(key)/disable")
    }

    private func makeRequest(path: String, method: String, requiresAuth: Bool) throws -> URLRequest {
        guard let url = URL(string: APIConfig.problemsBaseURL + path) else {
            throw ProblemsAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth {
            let token = KeychainService.shared.getAppStoreToken()
                ?? AuthService.shared.token()
            guard let token = token else {
                throw ProblemsAPIError.notAuthenticated
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func get<T: Decodable>(path: String, requiresAuth: Bool = true) async throws -> T {
        let request = try makeRequest(path: path, method: "GET", requiresAuth: requiresAuth)
        return try await perform(request)
    }

    private func put<T: Decodable>(path: String) async throws -> T {
        var request = try makeRequest(path: path, method: "PUT", requiresAuth: true)
        request.httpBody = try JSONEncoder().encode([String: String]())
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProblemsAPIError.invalidResponse
        }
        guard let http = response as? HTTPURLResponse else {
            throw ProblemsAPIError.invalidResponse
        }
        if http.statusCode == 401 {
            SessionManager.shared.handleUnauthorized()
            throw ProblemsAPIError.notAuthenticated
        }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"]
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ProblemsAPIError.serverError(http.statusCode, message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ProblemsAPIError.decodingFailed(error.localizedDescription)
        }
    }
}
