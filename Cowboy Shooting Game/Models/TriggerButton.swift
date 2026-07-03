//
//  TriggerButton.swift
//  Cowboy Shooting Game
//
//  Created by RyanMFDR on 03/07/26.
//

import Foundation

enum TriggerDirection {
    case up
    case down
}

struct TriggerState {
    var baselineTrigger: Float = 0.5
    var statusMessage: String = ""
    var showIndicator: Bool = false
}
