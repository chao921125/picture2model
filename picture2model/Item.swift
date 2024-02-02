//
//  Item.swift
//  picture2model
//
//  Created by 黄超 on 2024/2/2.
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
