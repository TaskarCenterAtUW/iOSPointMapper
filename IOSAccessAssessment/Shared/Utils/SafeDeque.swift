//
//  SafeDeque.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import DequeModule

public actor SafeDeque<Element: Sendable>: Sendable {
    private var storage = Deque<Element>()
    private let capacity: Int
    public var isEmpty: Bool { storage.isEmpty }
    public var count: Int { storage.count }
    
    public init(capacity: Int = 1) {
        self.capacity = capacity
    }
    
    /// Cheap value snapshot (copy-on-write)
    public func snapshot() -> Deque<Element> { storage }

    public subscript(index: Deque<Element>.Index) -> Element { storage[index] }
    
    public func appendBack(_ element: Element) {
        if storage.count >= capacity {
            _ = storage.popFirst()
        }
        storage.append(element)
    }
    
    public func appendFront(_ element: Element) {
        if storage.count >= capacity {
            _ = storage.popLast()
        }
        storage.prepend(element)
    }

    @discardableResult
    public func popBack() -> Element? {
        storage.popLast()
    }

    @discardableResult
    public func popFront() -> Element? {
        storage.popFirst()
    }

    public func removeAll(keepingCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepingCapacity)
    }
}

