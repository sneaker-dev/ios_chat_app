import SwiftUI

// MARK: - Opacity tokens (Problems tab)

/// Shared fill opacities so problem rows and the help tooltip read as one visual system; backdrop stays visible.
private enum ProblemsTabOpacity {
    /// Inactive problem row: `Color.white.opacity(problemRowInactiveFill)`.
    static let problemRowInactiveFill: Double = 0.10
    /// Enabled problem row tint: `Color.problemsRed.opacity(problemRowActiveFill)`.
    static let problemRowActiveFill: Double = 0.22
    /// Subtle edge for problem rows (inactive row overlay).
    static let chromeStroke: Double = 0.12
    /// Help speech bubble: more opaque than inactive rows so row copy does not read through the tooltip.
    static let helpTooltipFill: Double = 0.34
}

// MARK: - Color constants (Problems screen)

private extension Color {
    static let problemsRed      = Color(red: 0.718, green: 0.11,  blue: 0.11)   // #B71C1C
    static let problemsRedLight = Color(red: 0.898, green: 0.224, blue: 0.208)  // #E53935
    static let statusGreen      = Color(red: 0.298, green: 0.686, blue: 0.314)  // #4CAF50
    static let statusOrange     = Color(red: 1.0,   green: 0.596, blue: 0.0)    // #FF9800
    static let statusGray       = Color(red: 0.62,  green: 0.62,  blue: 0.62)
    static let problemsTextSecondary = Color.white.opacity(0.85)
}

// MARK: - ProblemsView

struct ProblemsView: View {
    @StateObject private var viewModel = ProblemsViewModel()
    /// Which row shows catalog help; `nil` when closed. Tap outside the tooltip dismisses.
    @State private var helpExpandedProblemKey: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            if viewModel.isLoading && viewModel.problems.isEmpty {
                loadingView
            } else if !viewModel.isLoading && viewModel.problems.isEmpty && viewModel.error != nil {
                errorView
            } else {
                problemsContentWithHelpDismiss
            }
        }
        .onAppear { viewModel.load() }
    }

    /// Scroll list with catalog help: tap outside the tooltip hits a full-screen clear layer *behind* the list while
    /// the list ignores taps, so any non-tooltip tap dismisses (and `?` still works when help is closed).
    private var problemsContentWithHelpDismiss: some View {
        ZStack {
            if helpExpandedProblemKey != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { helpExpandedProblemKey = nil }
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    headerView

                    if let err = viewModel.error {
                        inlineErrorBanner(err)
                    }

                    ForEach(viewModel.problems) { problem in
                        ProblemCard(
                            problem: problem,
                            helpExpandedKey: $helpExpandedProblemKey
                        ) { enable in
                            viewModel.toggleProblem(key: problem.key, enable: enable)
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .allowsHitTesting(helpExpandedProblemKey == nil)
        }
        .animation(.easeOut(duration: 0.18), value: helpExpandedProblemKey)
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

// MARK: - Help tooltip (overlay; speech-bubble shape; higher-opacity gray than row chrome)

/// Rounded body with a small tail on the **top** edge so it reads as a callout toward the help control above.
private struct ProblemsHelpBubbleShape: Shape {
    /// Tail tip X as a fraction of width from **leading** (0…1); default sits toward trailing for the `?` anchor.
    var tailCenterFraction: CGFloat = 0.82

    func path(in rect: CGRect) -> Path {
        let tailHeight: CGFloat = 7
        let tailWidth: CGFloat = 12
        let r = min(
            CGFloat(10),
            max(3, (rect.width - tailWidth) * 0.06),
            max(3, (rect.height - tailHeight) * 0.18)
        )
        let bodyTop = rect.minY + tailHeight
        let left = rect.minX
        let right = rect.maxX
        let bottom = rect.maxY

        var cx = left + rect.width * tailCenterFraction
        let minTailX = left + r + tailWidth * 0.5 + 2
        let maxTailX = right - r - tailWidth * 0.5 - 2
        cx = min(max(cx, minTailX), maxTailX)
        let tLeft = cx - tailWidth / 2
        let tRight = cx + tailWidth / 2

        var p = Path()
        p.move(to: CGPoint(x: left + r, y: bottom))
        p.addArc(
            center: CGPoint(x: left + r, y: bottom - r),
            radius: r,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: left, y: bodyTop + r))
        p.addArc(
            center: CGPoint(x: left + r, y: bodyTop + r),
            radius: r,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: tLeft, y: bodyTop))
        p.addLine(to: CGPoint(x: cx, y: rect.minY))
        p.addLine(to: CGPoint(x: tRight, y: bodyTop))
        p.addLine(to: CGPoint(x: right - r, y: bodyTop))
        p.addArc(
            center: CGPoint(x: right - r, y: bodyTop + r),
            radius: r,
            startAngle: Angle(degrees: 270),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: right, y: bottom - r))
        p.addArc(
            center: CGPoint(x: right - r, y: bottom - r),
            radius: r,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        p.addLine(to: CGPoint(x: left + r, y: bottom))
        p.closeSubpath()
        return p
    }
}

private struct ProblemsHelpTooltipPanel: View {
    let text: String

    private let tailReserve: CGFloat = 7

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(.black)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.top, 6 + tailReserve)
            .padding(.bottom, 12)
            .frame(maxWidth: 280, alignment: .leading)
            .background(
                ProblemsHelpBubbleShape(tailCenterFraction: 0.82)
                    .fill(Color.white.opacity(ProblemsTabOpacity.helpTooltipFill))
            )
            .overlay(
                ProblemsHelpBubbleShape(tailCenterFraction: 0.82)
                    .stroke(Color.white.opacity(ProblemsTabOpacity.chromeStroke), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.15), radius: 4, y: 1)
    }
}

// MARK: - ProblemCard

private struct ProblemCard: View {
    let problem: ProblemUiItem
    @Binding var helpExpandedKey: String?
    let onToggle: (Bool) -> Void

    private var helpText: String? {
        guard let s = problem.endUserDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty else { return nil }
        return s
    }

    private var isHelpExpanded: Bool {
        helpExpandedKey == problem.key
    }

    var body: some View {
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
                            if isHelpExpanded {
                                helpExpandedKey = nil
                            } else {
                                helpExpandedKey = problem.key
                            }
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
        .animation(.easeOut(duration: 0.18), value: isHelpExpanded)
        .zIndex(isHelpExpanded ? 2 : 0)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    problem.enabled
                        ? Color.problemsRed.opacity(ProblemsTabOpacity.problemRowActiveFill)
                        : Color.white.opacity(ProblemsTabOpacity.problemRowInactiveFill)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    problem.enabled ? Color.problemsRed.opacity(0.6) : Color.white.opacity(ProblemsTabOpacity.chromeStroke),
                    lineWidth: 1
                )
        )
        /// Tooltip is an overlay so it does not participate in row layout (no card height jump).
        .overlay(alignment: .topTrailing) {
            if isHelpExpanded, let hint = helpText {
                ProblemsHelpTooltipPanel(text: hint)
                    .transition(.opacity)
                    .padding(.top, 30)
                    .padding(.trailing, 56)
                    .allowsHitTesting(false)
            }
        }
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
