import SwiftUI

private extension Color {
    static let problemsRed      = Color(red: 0.718, green: 0.11,  blue: 0.11)
    static let problemsRedLight = Color(red: 0.898, green: 0.224, blue: 0.208)
    static let statusGreen      = Color(red: 0.298, green: 0.686, blue: 0.314)
    static let statusOrange     = Color(red: 1.0,   green: 0.596, blue: 0.0)
    static let statusGray       = Color(red: 0.62,  green: 0.62,  blue: 0.62)
}

struct ProblemsView: View {
    @StateObject private var viewModel = ProblemsViewModel()

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            if viewModel.isLoading && viewModel.problems.isEmpty {
                loadingView
            } else if !viewModel.isLoading && viewModel.problems.isEmpty && viewModel.error != nil {
                errorView
            } else {
                contentList
            }
        }
        .onAppear { viewModel.load() }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .problemsRed))
                .scaleEffect(1.4)
            Text("Loading problems…")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.problemsRed)
            Text(viewModel.error ?? "Failed to load problems.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                viewModel.load()
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color.problemsRed)
                    .clipShape(Capsule())
            }
        }
    }

    private var contentList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                headerView
                if let err = viewModel.error {
                    inlineErrorBanner(err)
                }
                ForEach(viewModel.problems) { problem in
                    ProblemCard(problem: problem) { enable in
                        viewModel.toggleProblem(key: problem.key, enable: enable)
                    }
                }
                Spacer().frame(height: 20)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Device Problems")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("Emulate hardware & network issues")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.55))
            }
            Spacer()
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
            }
        }
        .padding(.bottom, 4)
    }

    private func inlineErrorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(10)
        .background(Color.red.opacity(0.25))
        .cornerRadius(10)
    }
}

private struct ProblemCard: View {
    let problem: ProblemUiItem
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(problem.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(problem.enabled ? .white : .white.opacity(0.9))
                Text(problem.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(3)
                StatusBadge(status: problem.implementationStatus)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                if problem.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .problemsRedLight))
                        .frame(width: 32, height: 32)
                } else {
                    Toggle("", isOn: Binding(
                        get: { problem.enabled },
                        set: { onToggle($0) }
                    ))
                    .labelsHidden()
                    .tint(.problemsRed)
                    .frame(width: 51, height: 32)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    problem.enabled
                        ? Color.problemsRed.opacity(0.22)
                        : Color.white.opacity(0.10)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    problem.enabled ? Color.problemsRed.opacity(0.6) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
    }
}

private struct StatusBadge: View {
    let status: String

    private var badgeColor: Color {
        switch status.lowercased() {
        case "implemented": return .statusGreen
        case "partial":     return .statusOrange
        default:            return .statusGray
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.85))
            .clipShape(Capsule())
    }
}
