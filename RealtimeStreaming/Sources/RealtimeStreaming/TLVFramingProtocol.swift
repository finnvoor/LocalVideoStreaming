import Foundation
import Network

// MARK: - TLVFramingProtocol

class TLVFramingProtocol: NWProtocolFramerImplementation {
    // MARK: Lifecycle

    required init(framer _: NWProtocolFramer.Instance) {}

    // MARK: Internal

    static let definition = NWProtocolFramer.Definition(implementation: TLVFramingProtocol.self)

    static var label: String { String(describing: Self.self) }

    func wakeup(framer _: NWProtocolFramer.Instance) {}
    func start(framer _: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { .ready }
    func stop(framer _: NWProtocolFramer.Instance) -> Bool { true }
    func cleanup(framer _: NWProtocolFramer.Instance) {}

    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var tempHeader: TLVFramingProtocol.Header?
            let headerSize = TLVFramingProtocol.Header.encodedSize
            let parsed = framer.parseInput(
                minimumIncompleteLength: headerSize,
                maximumLength: headerSize
            ) { buffer, _ -> Int in
                guard let buffer else {
                    return 0
                }
                if buffer.count < headerSize {
                    return 0
                }
                tempHeader = TLVFramingProtocol.Header(buffer)
                return headerSize
            }

            guard parsed, let header = tempHeader else {
                return headerSize
            }

            let message = NWProtocolFramer.Message(messageType: MessageType(rawValue: header.type) ?? .unknown)

            if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
                return 0
            }
        }
    }

    func handleOutput(
        framer: NWProtocolFramer.Instance,
        message: NWProtocolFramer.Message,
        messageLength: Int,
        isComplete _: Bool
    ) {
        let header = TLVFramingProtocol.Header(
            type: message.messageType?.rawValue ?? MessageType.unknown.rawValue,
            length: UInt32(messageLength)
        )
        framer.writeOutput(data: header.encodedData)
        do {
            try framer.writeOutputNoCopy(length: messageLength)
        } catch {
            print("Error writing output: \(error)")
        }
    }
}

// MARK: TLVFramingProtocol.Header

extension TLVFramingProtocol {
    struct Header: Codable {
        // MARK: Lifecycle

        init(type: UInt32, length: UInt32) {
            self.type = type
            self.length = length
        }

        init(_ buffer: UnsafeMutableRawBufferPointer) {
            var tempType: UInt32 = 0
            var tempLength: UInt32 = 0
            withUnsafeMutableBytes(of: &tempType) { typePtr in
                typePtr.copyMemory(from: UnsafeRawBufferPointer(
                    start: buffer.baseAddress!.advanced(by: 0),
                    count: MemoryLayout<UInt32>.size
                ))
            }
            withUnsafeMutableBytes(of: &tempLength) { lengthPtr in
                lengthPtr.copyMemory(from: UnsafeRawBufferPointer(
                    start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
                    count: MemoryLayout<UInt32>.size
                ))
            }
            type = tempType
            length = tempLength
        }

        // MARK: Internal

        static var encodedSize: Int {
            MemoryLayout<UInt32>.size * 2
        }

        let type: UInt32
        let length: UInt32

        var encodedData: Data {
            var tempType = type
            var tempLength = length
            var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
            data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
            return data
        }
    }
}
