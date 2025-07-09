//
//  TableViewError.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

public struct ViewError: Error, Equatable, Sendable {
    public let message: String
    public let underlyingError: String?

    public init(message: String, underlyingError: Error? = nil) {
        self.message = message
        self.underlyingError = underlyingError?.localizedDescription
    }

    public static func == (lhs: ViewError, rhs: ViewError) -> Bool {
        return lhs.message == rhs.message && lhs.underlyingError == rhs.underlyingError
    }
}
