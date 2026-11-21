import Foundation

enum PearlReveal {
    static func isVisible(isBlessed: Bool, showsOpeningSleeve: Bool, presentsPlayer: Bool) -> Bool {
        isBlessed && !showsOpeningSleeve && !presentsPlayer
    }
}
