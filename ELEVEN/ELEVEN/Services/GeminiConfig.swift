//
//  GeminiConfig.swift
//  ELEVEN
//

import Foundation

enum GeminiConfig {
    
    static let apiKey    = "add your key here we used grok api you can use gemini key or somthing else"
    
  
    static let modelName = "llama-3.1-8b-instant"
    
    
    static let fallbackModel = "llama-3.3-70b-versatile"
    
    /// Groq endpoint (متوافق مع صيغة OpenAI)
    static var endpoint: String {
        "https://api.groq.com/openai/v1/chat/completions"
    }
}
