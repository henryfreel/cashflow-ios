import SwiftUI

// MARK: - View modifier

extension View {
    /// Presents a custom bottom sheet that:
    ///  - Goes edge-to-edge (no side margins, bleeds past the home-indicator safe area)
    ///  - Has 16 pt top corners; the device's own display corner radius provides
    ///    the bottom rounding for free at the screen edge
    ///  - Covers the tab bar (via ignoresSafeArea .bottom which extends into the
    ///    safeAreaInset created by ContentView's BottomTabBar)
    ///  - Supports drag-down to dismiss and drag-up to expand to full height
    func customBottomSheet<Content: View>(
        isPresented:   Binding<Bool>,
        compactHeight: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(CustomBottomSheetModifier(
            isPresented:   isPresented,
            compactHeight: compactHeight,
            sheetContent:  content
        ))
    }
}

// MARK: - Modifier implementation

struct CustomBottomSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented:  Bool
    let compactHeight:         CGFloat
    let sheetContent:          () -> SheetContent

    @State private var dragOffset: CGFloat = 0
    @State private var isExpanded: Bool    = false

    /// Height matching iOS's .large detent: screen height minus the top safe
    /// area inset and a small gap, so the sheet stops just below the camera bar.
    private var maxHeight: CGFloat {
        let topInset = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 59
        return UIScreen.main.bounds.height - topInset - 30
    }

    private var currentHeight: CGFloat {
        let base = isExpanded ? maxHeight : compactHeight
        return base + max(0, -dragOffset)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                ZStack(alignment: .bottom) {
                    // ── Dimming — zIndex 0, always below the sheet ─────────────────
                    if isPresented {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea(.all)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
                                    isPresented = false
                                }
                            }
                            .transition(.opacity)
                            .zIndex(0)
                    }

                    // ── Sheet card — zIndex 1, always above the dimming ────────────
                    if isPresented {
                        VStack(spacing: 0) {
                            sheetContent()
                        }
                        .padding(.top, 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: currentHeight, alignment: .top)
                        .background(Color.white)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius:    16,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: 0,
                                topTrailingRadius:   16
                            )
                        )
                        .overlay(alignment: .top) {
                            // Full-width drag handle zone floating above the white card.
                            // Contains the grabber pill and captures drag gestures so
                            // the user can grab anywhere in this zone to move the sheet.
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .fill(Color(white: 1.0, opacity: 0.5))
                                        .frame(width: 36, height: 5)
                                        .padding(.bottom, 12)
                                }
                                .gesture(
                                    DragGesture(minimumDistance: 10)
                                        .onChanged { value in
                                            dragOffset = value.translation.height
                                        }
                                        .onEnded { value in
                                            let dy = value.translation.height
                                            if dy > 60 {
                                                withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
                                                    isPresented = false
                                                }
                                            } else if dy < -60, !isExpanded {
                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                    isExpanded = true
                                                    dragOffset = 0
                                                }
                                            } else {
                                                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                                    dragOffset = 0
                                                }
                                            }
                                        }
                                )
                                .offset(y: -44)
                        }
                        .offset(y: max(0, dragOffset))
                        .ignoresSafeArea(edges: .bottom)
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    dragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    let dy = value.translation.height
                                    if dy > 100 {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 1.0)) {
                                            isPresented = false
                                        }
                                    } else if dy < -60, !isExpanded {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                            isExpanded = true
                                            dragOffset = 0
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                        .transition(.move(edge: .bottom))
                        .zIndex(1)
                        .onAppear {
                            dragOffset = 0
                            isExpanded = false
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all)
                .animation(.spring(response: 0.38, dampingFraction: 0.88), value: isPresented)
            }
    }
}
