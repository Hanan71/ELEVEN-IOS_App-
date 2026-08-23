//
//  NavigationRouter.swift
//  ELEVEN
//
//  
//
import SwiftUI
import Combine

enum AppDestination: String {
    case parentDashboard
    case childDashboard
    case aiRecommendations
}

@MainActor
final class NavigationRouter: ObservableObject {
    static let shared = NavigationRouter()
    
    @Published var currentDestination: AppDestination? = nil
    
    private init() {}
}
