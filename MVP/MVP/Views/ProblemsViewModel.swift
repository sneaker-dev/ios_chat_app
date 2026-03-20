import Foundation

struct ProblemUiItem: Identifiable {
    let key: String
    let title: String
    let summary: String
    let implementationStatus: String
    var enabled: Bool
    var isLoading: Bool = false

    var id: String { key }
}

@MainActor
final class ProblemsViewModel: ObservableObject {
    @Published var problems: [ProblemUiItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let api = ProblemsAPIService.shared

    func load() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                async let catalogTask = api.getCatalog()
                async let activeTask  = api.getActiveProblems()
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
                        enabled: state?.enabled ?? false
                    )
                }
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }

    func toggleProblem(key: String, enable: Bool) {
        guard let index = problems.firstIndex(where: { $0.key == key }) else { return }
        problems[index].enabled   = enable
        problems[index].isLoading = true

        Task {
            do {
                let response = enable
                    ? try await api.enableProblem(key: key)
                    : try await api.disableProblem(key: key)
                if let i = problems.firstIndex(where: { $0.key == key }) {
                    problems[i].enabled   = response.problem.enabled
                    problems[i].isLoading = false
                }
            } catch {
                if let i = problems.firstIndex(where: { $0.key == key }) {
                    problems[i].enabled   = !enable
                    problems[i].isLoading = false
                }
                self.error = error.localizedDescription
            }
        }
    }
}
