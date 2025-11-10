//
//  SafeDeque.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import DequeModule

actor SafeDeque<Element: Sendable> {
    private var storage = Deque<Element>()
    private let capacity: Int
    var isEmpty: Bool { storage.isEmpty }
    var count: Int { storage.count }
    
    init(capacity: Int = 1) {
        self.capacity = capacity
    }
    
    /// Cheap value snapshot (copy-on-write)
    func snapshot() -> Deque<Element> { storage }

    subscript(index: Deque<Element>.Index) -> Element { storage[index] }
    
    func appendBack(_ element: Element) {
        if storage.count >= capacity {
            _ = storage.popFirst()
        }
        storage.append(element)
    }
    
    func appendFront(_ element: Element) {
        if storage.count >= capacity {
            _ = storage.popLast()
        }
        storage.prepend(element)
    }

    @discardableResult
    func popBack() -> Element? {
        storage.popLast()
    }

    @discardableResult
    func popFront() -> Element? {
        storage.popFirst()
    }

    func removeAll(keepingCapacity: Bool = false) {
        storage.removeAll(keepingCapacity: keepingCapacity)
    }
}

