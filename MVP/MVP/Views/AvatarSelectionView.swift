//
//  AvatarSelectionView.swift
//  MVP
//
//  v2.0: Exact Android SwipeableAvatarSelectionScreen.kt match -
//  horizontal pager, arrows, page dots, 40% overlay

import SwiftUI

struct AvatarSelectionView: View {
    var onSelected: (AvatarType) -> Void
    @State private var selectedIndex: Int = 0
    @State private var isNavigating = false
    private let avatars = AvatarType.allCases

    var body: some View {
        ZStack {
            // Android: R.drawable.background, ContentScale.Crop
            if UIImage(named: "LoginBackground") != nil {
                Image("LoginBackground").resizable().scaledToFill().ignoresSafeArea().allowsHitTesting(false)
            } else {
                LinearGradient(
                    colors: [Color(red: 0x1A/255, green: 0x1A/255, blue: 0x2E/255),
                             Color(red: 0x0F/255, green: 0x0F/255, blue: 0x1E/255)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
            }

            // Android: Color.Black.copy(alpha = 0.4f)
            Color.black.opacity(0.4).ignoresSafeArea().allowsHitTesting(false)

            VStack(spacing: 0) {
                // Android: TopAppBar with title "Choose Your Assistant"
                HStack {
                    Text("Choose Your Assistant")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Android: instruction text "Swipe left or right to select"
                Text("Swipe left or right to select")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer().frame(height: 16) // Android: 16.dp

                // Avatar display with arrows
                ZStack {
                    // Avatar image (full size within the area)
                    TabView(selection: $selectedIndex) {
                        ForEach(Array(avatars.enumerated()), id: \.element) { index, avatar in
                            AvatarView(avatarType: avatar, state: .idle, scale: 1.0, showAsCircle: false)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(maxHeight: .infinity)

                    // Android: Left arrow "<" (56.dp, 50% black, 32.sp bold)
                    HStack {
                        if selectedIndex > 0 {
                            Button { withAnimation { selectedIndex -= 1 } } label: {
                                Text("<")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                        Spacer()
                        if selectedIndex < avatars.count - 1 {
                            Button { withAnimation { selectedIndex += 1 } } label: {
                                Text(">")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 56, height: 56)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16) // Android: 16.dp
                }
                .frame(maxHeight: .infinity)

                Spacer().frame(height: 16) // Android: 16.dp

                // Android: Page indicator dots
                HStack(spacing: 8) {
                    ForEach(0..<avatars.count, id: \.self) { i in
                        Circle()
                            .fill(i == selectedIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(
                                width: i == selectedIndex ? 12 : 8,
                                height: i == selectedIndex ? 12 : 8
                            )
                    }
                }

                Spacer().frame(height: 32) // Android: 32.dp

                // Android: Gender label (headlineSmall, Bold)
                Text(avatars[selectedIndex].isFemale ? "Female Assistant" : "Male Assistant")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Spacer().frame(height: 48) // Android: 48.dp

                // Android: Confirm button (56.dp, RoundedCornerShape(28.dp))
                Button {
                    guard !isNavigating else { return }
                    isNavigating = true
                    let avatar = avatars[selectedIndex]
                    KeychainService.shared.saveSelectedAvatar(avatar)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        onSelected(avatar)
                    }
                } label: {
                    Text("Select Assistant")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.appPrimary)
                        .cornerRadius(28) // Android: 28.dp
                }
                .padding(.horizontal, 16) // Android: 16.dp
                .disabled(isNavigating)

                Spacer().frame(height: 32)
            }
        }
    }
}
