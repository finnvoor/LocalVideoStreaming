import Network

extension NWProtocolFramer.Message {
    var messageType: MessageType? {
        self["messageType"] as? MessageType
    }

    convenience init(messageType: MessageType) {
        self.init(definition: TLVFramingProtocol.definition)
        self["messageType"] = messageType
    }
}
