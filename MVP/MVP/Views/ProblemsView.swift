import SwiftUI

// MARK: - Color constants (Problems screen)

private extension Color {
    static let problemsRed      = Color(red: 0.718, green: 0.11,  blue: 0.11)   // #B71C1C
    static let problemsRedLight = Color(red: 0.898, green: 0.224, blue: 0.208)  // #E53935
    static let statusGreen      = Color(red: 0.298, green: 0.686, blue: 0.314)  // #4CAF50
    static let statusOrange     = Color(red: 1.0,   green: 0.596, blue: 0.0)    // #FF9800
    static let statusGray       = Color(red: 0.62,  green: 0.62,  blue: 0.62)
    /// Help balloon surface (aligned with Android Problems `DarkCard`).
    static let problemsHelpSurface = Color(red: 0.118, green: 0.118, blue: 0.118).opacity(0.92)
    static let problemsTextPrimary = Color.white.opacity(0.92)
    static let problemsTextSecondary = Color.white.opacity(0.85)
}

// MARK: - ProblemsView

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

    // MARK: - Loading

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

    // MARK: - Error (empty state)

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

    // MARK: - Content list

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
        HStack(alignment: .center) {
            Text("Board Problem Emulation")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white.opacity(0.92))
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

// MARK: - ProblemCard

private struct ProblemCard: View {
    let problem: ProblemUiItem
    let onToggle: (Bool) -> Void

    @State private var showHelp = false

    private var helpText: String? {
        guard let s = problem.endUserDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 4) {
                        Text(problem.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if helpText != nil {
                            Button {
                                showHelp.toggle()
                            } label: {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.problemsTextSecondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Problem description help")
                        }
                    }

                    Text(problem.summary)
                        .font(.system(size: 12))
                        .foregroundColor(.problemsTextSecondary)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    StatusBadge(status: problem.implementationStatus)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showHelp, let hint = helpText {
                ZStack {
                    Color.black.opacity(0.001)
                        .contentShape(Rectangle())
                        .onTapGesture { showHelp = false }

                    Text(hint)
                        .font(.system(size: 13))
                        .foregroundColor(.problemsTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: 300)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.problemsHelpSurface)
                        )
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 40)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: showHelp)
        .zIndex(showHelp ? 1 : 0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    problem.enabled
                        ? Color.problemsRed.opacity(0.22)
                        : Color.white.opacity(0.10)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    problem.enabled ? Color.problemsRed.opacity(0.6) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
        .onChange(of: problem.key) { _ in showHelp = false }
    }
}

// MARK: - StatusBadge

private struct StatusBadge: View {
    let status: String

    private var badgeColor: Color {
        switch status.lowercased() {
        case "implemented": return .statusGreen
        case "partial":     return .statusOrange
        default:            return .statusGray
        }
    }

    private var label: String {
        status.capitalized
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(badgeColor.opacity(0.85))
            .clipShape(Capsule())
    }
}
