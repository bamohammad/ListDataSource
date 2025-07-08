//
//  EmptyStateConfiguration.swift
//  DataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import UIKit


public struct EmptyStateConfiguration: Equatable, @unchecked Sendable {
    public var title: String?
    public var subtitle: String?
    public var image: UIImage?
    public var backgroundColor: UIColor = .systemBackground

    public init(title: String? = nil,
                subtitle: String? = nil,
                image: UIImage? = nil,
                backgroundColor: UIColor = .systemBackground) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.backgroundColor = backgroundColor
    }

    public static func == (lhs: EmptyStateConfiguration, rhs: EmptyStateConfiguration) -> Bool {
        return lhs.title == rhs.title &&
            lhs.subtitle == rhs.subtitle &&
            lhs.image == rhs.image &&
            lhs.backgroundColor == rhs.backgroundColor
    }
}
