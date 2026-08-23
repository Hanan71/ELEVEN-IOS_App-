//
//  login.swift
//  ELEVEN
//

import SwiftUI

struct login: View {

    @AppStorage("childName") private var name: String = ""
    @State private var goToDashboard = false
    
    
   
    @State private var waveAngle: Double = -12

    var body: some View {
        VStack(spacing: 0) {

            Spacer()

           
            Text("👋")
                .font(.system(size: 68))
               
                .rotationEffect(.degrees(waveAngle), anchor: .bottom)
                .offset(x: -8) 
                .padding(.bottom, 10)

            Text("Hi There!")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black)
                .padding(.bottom, 56)

            VStack(spacing: 0) {

                Text("What's your name?")
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.55))
                    .padding(.bottom, 24)

                TextField("Enter your name", text: $name)
                    .font(.system(size: 18))
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 26)
                            .fill(
                                LinearGradient(
                                    colors: [Color(white: 0.87), Color(white: 0.965)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                                    .blur(radius: 0.6)
                                    .offset(y: 0.8)
                                    .mask(RoundedRectangle(cornerRadius: 26))
                            )
                    )
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: Color.black.opacity(0.10), radius: 3, x: 0, y: 2)
                    .padding(.bottom, 22)

                Button(action: {
                    goToDashboard = true
                }) {
                    Text("Let's go 🚀")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color(red: 0.93, green: 0.47, blue: 0.40))
                        .cornerRadius(27)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 16)

            Spacer()
            Spacer()
        }
        .background(Color(red: 245/255, green: 245/255, blue: 245/255).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // ✅ تلوح يمين ويسار حول النص بشكل متوازن
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) {
                    waveAngle = 12
                }
            }
        }
        .navigationDestination(isPresented: $goToDashboard) {
            KidsDashboardView()
        }
    }
}

#Preview {
    NavigationStack {
        login()
            .environmentObject(ActivityStore.shared)
    }
}
