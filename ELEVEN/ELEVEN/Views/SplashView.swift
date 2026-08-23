//
//  SplashView.swift
//  ELEVEN
//

import SwiftUI

struct SplashView: View {

    @State private var showLogin = false
    @State private var logoOpacity: Double = 0

    var body: some View {
        ZStack {
            
            Color.white.ignoresSafeArea()

            if showLogin {
                login()
                    .transition(.opacity)
            }

            if !showLogin {
                Image("logo")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .brightness(0.07)
                    .contrast(1.15)
                    .saturation(1.15)
                    .mask(
                        RoundedRectangle(cornerRadius: 60, style: .continuous)
                            .blur(radius: 12)
                            .padding(10)
                    )
                    .opacity(logoOpacity)
            }
        }
        .statusBarHidden(true)
        .onAppear {
         
            withAnimation(.easeInOut(duration: 0.4)) {
                logoOpacity = 1.0
            }

            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    logoOpacity = 0
                    showLogin = true
                }
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(ActivityStore.shared)
}
