import SwiftUI

struct PauseMenuView: View {
    @ObservedObject var matchController: MatchController
    
    // Using the font name from your folder structure
    let customFont = "WildWestPixel"
    let darkBrown = Color(red: 0.3, green: 0.15, blue: 0.1)
    let tanBackground = Color(red: 0.9, green: 0.75, blue: 0.5)
    
    var body: some View {
        ZStack {
            // 1. The Surrender Flag Button (Bottom Left)
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            matchController.isPaused = true
                        }
                    }) {
                        // Swap "flag_icon" with your actual asset name
                        Image(systemName: "flag.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .frame(width: 50, height: 50)
                            .foregroundColor(darkBrown)
                            .background(tanBackground)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(darkBrown, lineWidth: 4)
                            )
                    }
                    .padding(.leading, 30)
                    .padding(.bottom, 30)
                    
                    Spacer()
                }
            }
            
            // 2. The Confirmation Modal Overlay
            if matchController.isPaused {
                ZStack {
                    // Dark background dim
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()
                    
                    // Modal Box
                    VStack(spacing: 30) {
                        Text("Are you sure you want to surrender?")
                            .font(.custom(customFont, size: 24))
                            .foregroundColor(darkBrown)
                            .multilineTextAlignment(.center)
                            .padding(.top, 10)
                        
                        HStack(spacing: 30) {
                            // YES Button
                            Button(action: {
                                matchController.surrenderMatch()
                            }) {
                                Text("Yes")
                                    .font(.custom(customFont, size: 22))
                                    .foregroundColor(darkBrown)
                                    .frame(width: 120, height: 44)
                                    .background(tanBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(darkBrown, lineWidth: 6)
                                    )
                            }
                            
                            // NO Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    matchController.isPaused = false
                                }
                            }) {
                                Text("No")
                                    .font(.custom(customFont, size: 22))
                                    .foregroundColor(darkBrown)
                                    .frame(width: 120, height: 44)
                                    .background(tanBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(darkBrown, lineWidth: 6)
                                    )
                            }
                        }
                    }
                    .padding(30)
                    .background(Color(red: 0.95, green: 0.8, blue: 0.55)) // Lighter tan for the main box
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(darkBrown, lineWidth: 8)
                    )
                    .padding(.horizontal, 40)
                }
            }
        }
    }
}
