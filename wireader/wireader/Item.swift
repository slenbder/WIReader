//
//  Item.swift
//  wireader
//
//  Created by Кирилл Марьясов on 6/9/26.
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
