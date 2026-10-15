import Combine
import Foundation
import Network

public enum GeloBonjour {
    public static let serviceType = "_gelokaraoke._tcp"
}

public struct DiscoveredKaraokeHost:
    Identifiable,
    Hashable,
    Sendable
{
    public let id: String
    public let name: String
    public let domain: String
    public let interfaceName: String?

    public init(
        id: String,
        name: String,
        domain: String,
        interfaceName: String?
    ) {
        self.id = id
        self.name = name
        self.domain = domain
        self.interfaceName = interfaceName
    }
}

public enum BonjourBrowserStatus:
    Equatable,
    Sendable
{
    case idle
    case searching
    case ready
    case failed(String)
}

@MainActor
public final class BonjourHostBrowser: ObservableObject {
    @Published public private(set) var hosts:
        [DiscoveredKaraokeHost] = []
    @Published public private(set) var status:
        BonjourBrowserStatus = .idle

    private var lifecycleGeneration = UUID()
    private var browser: NWBrowser?
    private let queue = DispatchQueue(
        label: "com.gelo.karaoke.bonjour.browser"
    )

    public init() {}

    deinit {
        browser?.cancel()
    }

    public func start() {
        guard browser == nil else { return }
        let generation = UUID()
        lifecycleGeneration = generation

        status = .searching

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(
            for: .bonjour(
                type: GeloBonjour.serviceType,
                domain: nil
            ),
            using: parameters
        )

        browser.stateUpdateHandler = { [weak self] state in
            let nextStatus: BonjourBrowserStatus
            switch state {
            case .setup, .waiting:
                nextStatus = .searching
            case .ready:
                nextStatus = .ready
            case let .failed(error):
                nextStatus = .failed(error.localizedDescription)
            case .cancelled:
                nextStatus = .idle
            @unknown default:
                nextStatus = .searching
            }

            Task { @MainActor [weak self] in
                guard let self, self.lifecycleGeneration == generation else { return }
                self.status = nextStatus
            }
        }

        browser.browseResultsChangedHandler = {
            [weak self] results, _ in
            let mapped = Self.map(results: results)
            Task { @MainActor [weak self] in
                guard let self, self.lifecycleGeneration == generation else { return }
                self.hosts = mapped
            }
        }

        self.browser = browser
        browser.start(queue: queue)
    }

    public func stop() {
        lifecycleGeneration = UUID()
        browser?.cancel()
        browser = nil
        hosts = []
        status = .idle
    }

    private nonisolated static func map(
        results: Set<NWBrowser.Result>
    ) -> [DiscoveredKaraokeHost] {
        var hostsByID: [String: DiscoveredKaraokeHost] = [:]

        for result in results {
            guard case let .service(
                name,
                _,
                domain,
                interface
            ) = result.endpoint else {
                continue
            }

            let interfaceName = interface?.name
            let id = [
                name,
                domain,
                interfaceName ?? ""
            ]
            .joined(separator: "|")

            hostsByID[id] = DiscoveredKaraokeHost(
                id: id,
                name: name,
                domain: domain,
                interfaceName: interfaceName
            )
        }

        return hostsByID.values.sorted {
            let order = $0.name.localizedStandardCompare(
                $1.name
            )
            if order != .orderedSame {
                return order == .orderedAscending
            }
            return $0.id < $1.id
        }
    }
}


