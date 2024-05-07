import Network

extension NWParameters {
    static var castaway: NWParameters {
        let options = NWProtocolTCP.Options()
        options.enableKeepalive = true
        options.keepaliveIdle = 2
        options.keepaliveCount = 2
        options.keepaliveInterval = 2
        options.connectionTimeout = 5
        options.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: options)
        parameters.serviceClass = .interactiveVideo
        let tlvFramer = NWProtocolFramer.Options(definition: TLVFramingProtocol.definition)
        parameters.defaultProtocolStack.applicationProtocols.insert(tlvFramer, at: 0)
        return parameters
    }
}
