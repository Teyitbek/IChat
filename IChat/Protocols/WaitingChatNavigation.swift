
import Foundation

protocol WaitingChatNavigation: AnyObject {
    func removeWaitingChat(chat: MChat)
    func chatToActive(chat: MChat)
}
