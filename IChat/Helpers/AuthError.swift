

import Foundation
import SwiftUI

enum AuthError {
    case notFilled
    case invalidEmail
    case passwordsNotMatched
    case unknownError
    case ServerError
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notFilled:
            return NSLocalizedString("Fill All Fields", comment: "")
        case .invalidEmail:
            return NSLocalizedString("Invalid Email", comment: "")
        case .passwordsNotMatched:
            return NSLocalizedString("Passwords Not Matched", comment: "")
        case .unknownError:
            return NSLocalizedString("Unknown Error", comment: "")
        case .ServerError:
            return NSLocalizedString("Server Error", comment: "")
        }
    }
}
