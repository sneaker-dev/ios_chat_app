import Foundation

// MARK: - UI model

struct ProblemUiItem: Identifiable {
    let key: String
    let title: String
    let summary: String
    let implementationStatus: String
    /// Catalog `description` only; nil hides the help control (Redmine #45250).
    let endUserDescription: String?
    var enabled: Bool
    var isLoading: Bool = false

    var id: String { key }
}

private extension Optional where Wrapped == String {
    /// Non-empty trimmed catalog `description`, else nil.
    func normalizedEndUserDescription() -> String? {
        guard let s = self?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }
}

// MARK: - ViewModel

@MainActor
final class ProblemsViewModel: ObservableObject {
    @Published var problems: [ProblemUiItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let api = ProblemsAPIService.shared

    /// Shown when the backend has no Problems API for this tenant/device (often HTTP 404/403).
    private static let problemsNotAvailableMessage =
        "Problem emulation is not available for this account or linked device. If you need it, check with your administrator."

    // MARK: - Load

    func load() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                async let catalogTask  = api.getCatalog()
                async let activeTask   = api.getActiveProblems()

                let (catalog, active) = try await (catalogTask, activeTask)

                let activeMap = Dictionary(
                    uniqueKeysWithValues: active.activeProblems.map { ($0.key, $0) }
                )

                problems = catalog.items.map { item in
                    let state = activeMap[item.key]
                    return ProblemUiItem(
                        key: item.key,
                        title: item.title,
                        summary: item.summary,
                        implementationStatus: item.implementationStatus,
                        endUserDescription: item.description.normalizedEndUserDescription(),
                        enabled: state?.enabled ?? false
                    )
                }
            } catch {
                self.error = Self.userFacingProblemsError(error)
            }
            isLoading = false
        }
    }

    // MARK: - Toggle

    func toggleProblem(key: String, enable: Bool) {
        guard let index = problems.firstIndex(where: { $0.key == key }) else { return }

        // Optimistic update
        problems[index].enabled = enable
        problems[index].isLoading = true

        Task {
            do {
                let response = enable
                    ? try await api.enableProblem(key: key)
                    : try await api.disableProblem(key: key)

                if let i = problems.firstIndex(where: { $0.key == key }) {
                    let prev = problems[i]
                    problems[i] = ProblemUiItem(
                        key: prev.key,
                        title: prev.title,
                        summary: prev.summary,
                        implementationStatus: prev.implementationStatus,
                        endUserDescription: prev.endUserDescription,
                        enabled: response.problem.enabled,
                        isLoading: false
                    )
                }
            } catch {
                // Revert optimistic update on failure
                if let i = problems.firstIndex(where: { $0.key == key }) {
                    problems[i].enabled   = !enable
                    problems[i].isLoading = false
                }
                self.error = Self.userFacingProblemsError(error)
            }
        }
    }

    private static func userFacingProblemsError(_ error: Error) -> String {
        if let api = error as? ProblemsAPIError {
            switch api {
            case .serverError(let code, _) where code == 404 || code == 403:
                return problemsNotAvailableMessage
            default:
                return api.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
