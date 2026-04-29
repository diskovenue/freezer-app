import Foundation

extension Notification.Name {
    static let inventoryDataDidChange = Notification.Name("inventoryDataDidChange")
    static let openAttentionTab = Notification.Name("openAttentionTab")
    static let unitDetailDidConsume = Notification.Name("unitDetailDidConsume")
}

enum AppNotificationKey {
    static let unitID = "unitID"
    static let title = "title"
}
