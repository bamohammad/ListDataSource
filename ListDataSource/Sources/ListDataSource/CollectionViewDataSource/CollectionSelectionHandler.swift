//
//  CollectionSelectionHandler.swift
//  ListDataSource
//
//  Created by Ali Bamohammad on 08/07/2025.
//
import Foundation

@MainActor
public final class CollectionSelectionHandler {
    private var handlers: [String: (Any) -> Void] = [:]

    public init() {}

    public func addHandler<T>(for type: T.Type, handler: @escaping (T) -> Void) {
        let typeKey = String(describing: type)
        handlers[typeKey] = { item in
            if let cellItem = item as? CollectionViewCellItem<T> {
                handler(cellItem.item)
            }
        }
    }
    
    public func handle(item: any CollectionCellItem) {
        let typeKey = String(describing: item.itemType)
        handlers[typeKey]?(item)
    }
}
