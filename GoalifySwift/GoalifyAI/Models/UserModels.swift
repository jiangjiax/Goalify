import Foundation
import SwiftData

@Model
final class User {
    var id: UUID
    var username: String
    var email: String
    var energy: Int
    
    init(id: UUID = UUID(), username: String, email: String, energy: Int = 20) {
        self.id = id
        self.username = username
        self.email = email
        self.energy = energy
    }
} 