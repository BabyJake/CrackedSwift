//
//  Item.swift
//  CrackedSwift
//
//  Created by Jacob Taylor on 02/11/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
