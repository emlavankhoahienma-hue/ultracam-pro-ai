import Foundation
import UIKit
import Combine

public enum LUTPreset: Int, CaseIterable, Identifiable {
    case natural = 0
    case fujiClassicChrome = 1
    case kodakPortra400 = 2
    case leicaMonochrome = 3
    case cinestill800T = 4
    case tealOrange = 5
    
    public var id: Int { rawValue }
    
    public var displayName: String {
        switch self {
        case .natural: return "NATURAL"
        case .fujiClassicChrome: return "FUJI CHROME"
        case .kodakPortra400: return "PORTRA 400"
        case .leicaMonochrome: return "LEICA B&W"
        case .cinestill800T: return "CINESTILL"
        case .tealOrange: return "TEAL & ORANGE"
        }
    }
    
    public var shortBadge: String {
        switch self {
        case .natural: return "NAT"
        case .fujiClassicChrome: return "FUJI"
        case .kodakPortra400: return "PORT"
        case .leicaMonochrome: return "B&W"
        case .cinestill800T: return "CINE"
        case .tealOrange: return "T&O"
        }
    }
}

public final class LUTEngine: ObservableObject {
    @Published public var activePreset: LUTPreset = .natural
    @Published public var intensity: Float = 1.0 // 0.0 to 1.0
    @Published public var isLUTPanelOpen: Bool = false
    
    public init() {}
    
    public func selectPreset(_ preset: LUTPreset) {
        self.activePreset = preset
    }
}
