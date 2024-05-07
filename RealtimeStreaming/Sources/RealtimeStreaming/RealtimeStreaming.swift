import Foundation
import Network

@Observable public final class RealtimeStreaming {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var isConnected = false

    public var receivedMessages: AsyncStream<(Data, MessageType)> {
        .init { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                self?.continuations[id] = nil
            }
        }
    }

    public func attemptToReconnect() {
        browserResultsFound(browser?.browseResults ?? [])
    }

    public func disconnect() {
        connection?.cancel()
    }

    public func startBrowsing(for serviceType: String) {
        guard browser?.state != .ready else { return }
        print("Starting browsing")
        browser?.cancel()
        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .castaway)
        browser?.stateUpdateHandler = { [weak self] state in
            print("Browser chaged to state: \(state)")
            guard let self else { return }
            switch state {
            case .ready:
                browserResultsFound(browser?.browseResults ?? [])
            case let .failed(error):
                print("Browsing failed with error: \(error)")
                if case let .dns(error) = error, error == kDNSServiceErr_DefunctConnection {
                    startBrowsing(for: serviceType)
                }
            default: break
            }
        }
        browser?.browseResultsChangedHandler = { [weak self] _, _ in
            self?.browserResultsFound(self?.browser?.browseResults ?? [])
        }
        browser?.start(queue: browserQueue)
    }

    public func startListening(for serviceType: String) {
        guard listener?.state != .ready else { return }
        print("Starting listening")
        listener?.cancel()
        listener = try? NWListener(
            service: .init(type: serviceType),
            using: .castaway
        )
        listener?.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            print("Listener chaged to state: \(state)")
            switch state {
            case let .failed(error):
                print("Listening failed with error: \(error)")
                if case let .dns(error) = error, error == kDNSServiceErr_DefunctConnection {
                    startListening(for: serviceType)
                }
            default: break
            }
        }
        listener?.newConnectionHandler = { [weak self] connection in
            guard self?.connection?.state != .ready else { return }
            self?.startConnection(connection)
        }
        listener?.start(queue: listenerQueue)
    }

    public func stopListening() {
        listener?.cancel()
    }

    public func send(data: Data, messageType: MessageType) async throws {
        guard let connection else { return }

        let message = NWProtocolFramer.Message(messageType: messageType)
        let contentContext = NWConnection.ContentContext(identifier: "message", metadata: [message])

        try await withCheckedThrowingContinuation { continuation in
            connection.send(
                content: data,
                contentContext: contentContext,
                isComplete: true,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        } as Void
    }

    // MARK: Private

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private lazy var browserQueue = DispatchQueue(
        label: "\(String(describing: Self.self)).browser"
    )

    @ObservationIgnored private var listener: NWListener?
    @ObservationIgnored private lazy var listenerQueue = DispatchQueue(
        label: "\(String(describing: Self.self)).listener"
    )

    @ObservationIgnored private lazy var connectionQueue = DispatchQueue(
        label: "\(String(describing: Self.self)).connection"
    )

    @ObservationIgnored private var connection: NWConnection?

    @ObservationIgnored private var continuations: [UUID: AsyncStream<(Data, MessageType)>.Continuation] = [:]

    private func browserResultsFound(_ results: Set<NWBrowser.Result>) {
        for result in results {
            print("Found endpoint \(result.endpoint) on interfaces: \(result.interfaces)")
        }
        guard let result = results.first, connection?.state != .ready else { return }
        let connection = NWConnection(to: result.endpoint, using: .castaway)
        startConnection(connection)
    }

    private func startConnection(_ connection: NWConnection) {
        print("Starting connection")
        self.connection?.cancel()
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.isConnected = self?.connection?.state == .ready
            }
            print("Connection changed to state \(state)")
            switch state {
            case .ready:
                self?.receiveMessage()
            case let .failed(error):
                print("Connection failed with error: \(error)")
            default: break
            }
        }
        connection.start(queue: connectionQueue)
    }

    private func receiveMessage() {
        guard let connection else { return }

        connection.receiveMessage { [weak self] content, contentContext, _, error in
            guard let self else { return }
            guard !(contentContext?.isFinal ?? true) else {
                self.connection?.cancel()
                return
            }
            if let message = contentContext?.protocolMetadata(
                definition: TLVFramingProtocol.definition
            ) as? NWProtocolFramer.Message,
                let data = content {
                for continuation in continuations.values {
                    continuation.yield((data, message.messageType ?? .unknown))
                }
            }
            if let error {
                print("receiveMessage failed with error: \(error)")
            } else {
                receiveMessage()
            }
        }
    }
}
