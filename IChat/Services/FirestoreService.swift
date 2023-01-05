
import Firebase
import FirebaseFirestore


class FirestoreService {
    static let shared = FirestoreService()
    let db = Firestore.firestore()
    
    private var userRef: CollectionReference {
        return db.collection("users")
    }
    
    private var waitingChatRef: CollectionReference {
        return db.collection(["users", currentUser.id, "waitingChats"].joined(separator: "/"))
    }
    
    private var activeChatRef: CollectionReference {
        return db.collection(["users", currentUser.id, "activeChats"].joined(separator: "/"))
    }
    
    var currentUser: MUser!
    
    func getUserData(user: User, completion: @escaping (Result<MUser, Error>) -> Void) {
        let docRef = userRef.document(user.uid)
        docRef.getDocument { (document, error) in
            if let document = document, document.exists {
                guard let muser = MUser(document: document) else {
                    completion(.failure(UserError.cannotUnwrapToMUser))
                    return
                }
                self.currentUser = muser
                completion(.success(muser))
            }
            else {
                completion(.failure(UserError.cannotGetUserInfo))
            }
        }
    }
    
    func saveProfileWith(id: String, email: String, username: String?, avatarImageString: String?,  description: String?, sex: String?,  completion: @escaping (Result<MUser, Error>) -> Void) {
        
        guard Validators.isFilled(username: username, description: description, sex: sex) else {
            completion(.failure(UserError.notFilled))
            return 
        }
        
        
        let muser = MUser(username: username!, email: email, avatarStringURL: "not exist",
                          descrition: description!, sex: sex!, id: id)
        
        self.userRef.document(muser.id).setData(muser.representation) { (error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(muser))
            }
        }
    }
    
    func createWaitingChatIfNeeded(message: String, reseiver: MUser, completion: @escaping (Result<Void, Error>) -> Void) {
        let currentActiveRef = db.collection(["users", currentUser.id, "activeChats"].joined(separator: "/"))
        let currentActiveDocumentRef = currentActiveRef.document(reseiver.id)
        
        let receiverActiveRef = db.collection(["users", reseiver.id, "activeChats"].joined(separator: "/"))
        let receiverActiveDocumentRef = receiverActiveRef.document(currentUser.id)
        
        receiverActiveDocumentRef.getDocument { document, error in
            if let document = document, document.exists {
                let currentMessage = MMessage(user: reseiver, content: message)
                let currentActiveMessagesRef = currentActiveDocumentRef.collection("messages")
                let currentChat = MChat(friendUsername: reseiver.username,
                                        lastMessageContent: message,
                                        friendId: reseiver.id)
                
                let group = DispatchGroup()
                
                group.enter()
                currentActiveDocumentRef.setData(currentChat.representation) { (error) in
                    group.leave()
                }
                
                group.enter()
                currentActiveMessagesRef.addDocument(data: currentMessage.representation) { (error) in
                    group.leave()
                }
                
                let recieverMessage = MMessage(user: self.currentUser, content: message)
                let receiverMessagesRef = receiverActiveDocumentRef.collection("messages")
                let receiverChat = MChat(friendUsername: self.currentUser.username,
                                         lastMessageContent: message,
                                         friendId: self.currentUser.id)
                // MARK: add error handler
                group.enter()
                receiverActiveDocumentRef.setData(receiverChat.representation) { (error) in
                    if error != nil {
                        completion(.failure(error!))
                    }
                    group.leave()
                }
                
                group.enter()
                receiverMessagesRef.addDocument(data: recieverMessage.representation) { (error) in
                    group.leave()
                    if error != nil {
                        completion(.failure(error!))
                        return
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(Void()))
                }
            } else {
                self.createWaitingChat(message: message, reseiver: reseiver, completion: completion)
            }
        }
    }
    
    private func createWaitingChat(message: String, reseiver: MUser, completion: @escaping (Result<Void, Error>) -> Void) {
        let reference = db.collection(["users", reseiver.id, "waitingChats"].joined(separator: "/"))
        let messageRef = reference.document(self.currentUser.id).collection("messages") // Error id

        let message = MMessage(user: currentUser, content: message)
        let chat = MChat(friendUsername: currentUser.username,
                         lastMessageContent: message.content,
                         friendId: currentUser.id)

        reference.document(currentUser.id).setData(chat.representation) { (error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            messageRef.addDocument(data: message.representation) { (error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(Void()))
            }
        }
    }
    
    func deleteWaitingChat(chat: MChat, completion: @escaping (Result<Void, Error>) -> Void) {
        waitingChatRef.document(chat.friendId).delete { (error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            self.deleteMessages(chat: chat, completion: completion)
        }
    }
    
    func deleteMessages(chat: MChat, completion: @escaping (Result<Void, Error>) -> Void) {
        let reference = waitingChatRef.document(chat.friendId).collection("messages")
        
        getWaitingChatMessages(chat: chat) { (result) in
            switch result {
            case .success(let messages):
                for message in messages {
                    guard let documentId = message.id else { return }
                    let messageRef = reference.document(documentId)
                    messageRef.delete { (error) in
                        if let error = error {
                            completion(.failure(error))
                            return
                        }
                        completion(.success(Void()))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getWaitingChatMessages(chat: MChat, comletion: @escaping (Result<[MMessage], Error>) -> Void) {
        let reference = waitingChatRef.document(chat.friendId).collection("messages")
        var messages = [MMessage]()
        reference.getDocuments { (querySnapshot, error) in
            if let error = error {
                comletion(.failure(error))
                return
            }
            for document in querySnapshot!.documents {
                guard let message = MMessage(document: document) else { return }
                messages.append(message)
            }
            comletion(.success(messages))
        }
    }
    // MARK: Call all funcs
    func changeToActive(chat: MChat, completion: @escaping (Result<Void, Error>) -> Void) {
        getWaitingChatMessages(chat: chat) { (result) in
            switch result {
            case .success(let messages):
                self.deleteWaitingChat(chat: chat) { (result) in
                    switch result {
                    case .success:
                        self.createActiveChat(chat: chat, messages: messages) { (result) in
                            switch result {
                            case .success:
                                completion(.success(Void()))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    func createActiveChat(chat: MChat, messages: [MMessage], completion: @escaping (Result<Void, Error>) -> Void) {
        let messageRef = activeChatRef.document(chat.friendId).collection("messages")
        activeChatRef.document(chat.friendId).setData(chat.representation) { (error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            for message in messages {
                messageRef.addDocument(data: message.representation) { (error) in
                    if let error = error {
                        completion(.failure(error))
                        return
                    }
                    completion(.success(Void()))
                }
            }
        }
    }
    func sendMessage(chat: MChat, message: MMessage, completion: @escaping (Result<Void, Error>) -> Void) {
        let friendRef = userRef.document(chat.friendId).collection("activeChats").document(currentUser.id)
        let friendMessageRef = friendRef.collection("messages")
        let myMessageRef = userRef.document(currentUser.id).collection("activeChats").document(chat.friendId).collection("messages")
        let chatForFriend = MChat(friendUsername: currentUser.username,
                                  lastMessageContent: message.content,
                                  friendId: currentUser.id)
        friendRef.setData(chatForFriend.representation) { (error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            friendMessageRef.addDocument(data: message.representation) { (error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                myMessageRef.addDocument(data: message.representation) { (error) in
                    if let error = error {
                        completion(.failure(error))
                        return 
                    }
                    completion(.success(Void()))
                }
            }
        }
    }
}
