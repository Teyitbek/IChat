
import Foundation

enum UserError {
    case notFilled
    case photoNotExist
    case cannotGetUserInfo
    case cannotUnwrapToMUser
}

extension UserError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFilled:
            return NSLocalizedString("Fill all Field", comment: "")
        case .photoNotExist:
            return NSLocalizedString("User not chosed a photo", comment: "")
        case .cannotGetUserInfo:
            return NSLocalizedString("Can not download info abou user from Firebase", comment: "")
        case .cannotUnwrapToMUser:
            return NSLocalizedString("Can't convert MUser from User", comment: "")
        }
    }
}
