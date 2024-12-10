//
//  NetworkError.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 27.11.2024.
//

import Foundation

enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case serverError(message: String)
    case decodingError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .noData:
            return "No data received from the server."
        case .invalidResponse:
            return "Invalid response from the server."
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode the response from the server."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}
