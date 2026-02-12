import Foundation
import Combine
import MultipeerConnectivity
import os.log
#if os(iOS)
import UIKit
#endif

// MARK: - Connection State

enum SyncConnectionState: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting…"
    case connected = "Connected"
}

// MARK: - Sync Service

/// Manages Multipeer Connectivity for syncing health data between iOS and macOS.
///
/// - iOS: Advertises as a data source (MCNearbyServiceAdvertiser)
/// - macOS: Browses for iPhones (MCNearbyServiceBrowser)
/// - Both: Sends and receives `SyncMessage` via MCSession
@MainActor
final class SyncService: NSObject, ObservableObject {

    // MARK: - Constants

    static let serviceType = "healthmd-sync" // 1-15 chars, lowercase + hyphens

    // MARK: - Published State

    @Published var connectionState: SyncConnectionState = .disconnected
    @Published var connectedPeerName: String?
    @Published var lastError: String?
    @Published var discoveredPeers: [MCPeerID] = []

    /// Whether a sync operation is actively in progress.
    /// Setting this keeps the device awake (iOS) and requests background execution time.
    @Published var isSyncing: Bool = false {
        didSet {
            guard oldValue != isSyncing else { return }
            if isSyncing {
                beginKeepAwake()
            } else {
                endKeepAwake()
            }
        }
    }

    // MARK: - Keep-Awake State

    #if os(iOS)
    /// Background task identifier so the sync can finish if the app is briefly backgrounded.
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    #endif

    // MARK: - Callback

    /// Called when a `SyncMessage` is received from the connected peer.
    var onMessageReceived: ((SyncMessage) -> Void)?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.codybontecou.obsidianhealth", category: "SyncService")
    private let myPeerID: MCPeerID
    private let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: - Init

    override init() {
        #if os(iOS)
        let deviceName = UIDevice.current.name
        #elseif os(macOS)
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif

        self.myPeerID = MCPeerID(displayName: deviceName)
        self.session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)

        super.init()

        // MCSessionDelegate is nonisolated — assign via nonisolated helper
        session.delegate = self
    }

    deinit {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }

    // MARK: - iOS: Advertising

    /// Start advertising this device as a health data source (iOS).
    func startAdvertising() {
        guard advertiser == nil else { return }
        logger.info("Starting advertiser")
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        self.advertiser = adv
    }

    /// Stop advertising.
    func stopAdvertising() {
        logger.info("Stopping advertiser")
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - macOS: Browsing

    /// Start browsing for nearby iPhones (macOS).
    func startBrowsing() {
        guard browser == nil else { return }
        logger.info("Starting browser")
        discoveredPeers = []
        let br = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        self.browser = br
    }

    /// Stop browsing.
    func stopBrowsing() {
        logger.info("Stopping browser")
        browser?.stopBrowsingForPeers()
        browser = nil
        discoveredPeers = []
    }

    /// Invite a discovered peer to connect (macOS → iOS).
    func connectToPeer(_ peer: MCPeerID) {
        logger.info("Inviting peer: \(peer.displayName)")
        connectionState = .connecting
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }

    // MARK: - Disconnect

    func disconnect() {
        logger.info("Disconnecting session")
        isSyncing = false
        session.disconnect()
        connectionState = .disconnected
        connectedPeerName = nil
    }

    // MARK: - Sending Messages

    /// Send a `SyncMessage` to all connected peers.
    func send(_ message: SyncMessage) {
        guard !session.connectedPeers.isEmpty else {
            logger.warning("Cannot send — no connected peers")
            lastError = "No connected device"
            return
        }

        do {
            let data = try encoder.encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            logger.info("Sent message: \(String(describing: message).prefix(80))")
        } catch {
            logger.error("Failed to send message: \(error.localizedDescription)")
            lastError = "Send failed: \(error.localizedDescription)"
        }
    }

    /// Send a `SyncMessage` using streaming for large payloads.
    func sendLargePayload(_ message: SyncMessage) {
        guard let peer = session.connectedPeers.first else {
            logger.warning("Cannot send — no connected peers")
            lastError = "No connected device"
            return
        }

        do {
            let data = try encoder.encode(message)

            // For payloads > 100KB, use resource transfer for reliability
            if data.count > 100_000 {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("sync_\(UUID().uuidString).json")
                try data.write(to: tempURL)

                session.sendResource(at: tempURL, withName: "sync-payload", toPeer: peer) { error in
                    try? FileManager.default.removeItem(at: tempURL)
                    if let error {
                        Task { @MainActor in
                            self.logger.error("Resource send failed: \(error.localizedDescription)")
                            self.lastError = "Send failed: \(error.localizedDescription)"
                        }
                    }
                }
                logger.info("Sending large payload via resource transfer (\(data.count) bytes)")
            } else {
                try session.send(data, toPeers: [peer], with: .reliable)
                logger.info("Sent message (\(data.count) bytes)")
            }
        } catch {
            logger.error("Failed to encode/send message: \(error.localizedDescription)")
            lastError = "Send failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Keep-Awake Helpers

    /// Prevent the device from sleeping and request background execution time while syncing.
    private func beginKeepAwake() {
        #if os(iOS)
        logger.info("Sync started — disabling idle timer and requesting background time")
        UIApplication.shared.isIdleTimerDisabled = true

        // Request background execution time so the sync survives brief app-backgrounding
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "HealthMD-Sync") { [weak self] in
            // Expiration handler — system is about to kill background time
            Task { @MainActor in
                self?.logger.warning("Background time expiring — ending background task")
                self?.endBackgroundTask()
            }
        }
        #endif
    }

    /// Re-enable idle timer and end background task assertion.
    private func endKeepAwake() {
        #if os(iOS)
        logger.info("Sync finished — re-enabling idle timer")
        UIApplication.shared.isIdleTimerDisabled = false
        endBackgroundTask()
        #endif
    }

    #if os(iOS)
    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
    #endif

    // MARK: - Private Helpers

    private func handleReceivedData(_ data: Data) {
        do {
            let message = try decoder.decode(SyncMessage.self, from: data)
            logger.info("Received message: \(String(describing: message).prefix(80))")
            Task { @MainActor in
                self.onMessageReceived?(message)
            }
        } catch {
            logger.error("Failed to decode received message: \(error.localizedDescription)")
            Task { @MainActor in
                self.lastError = "Decode error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - MCSessionDelegate

extension SyncService: MCSessionDelegate {

    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peerName = peerID.displayName
        Task { @MainActor in
            switch state {
            case .notConnected:
                self.logger.info("Peer disconnected: \(peerName)")
                self.connectionState = .disconnected
                self.connectedPeerName = nil
                if self.isSyncing {
                    self.logger.warning("Peer disconnected during active sync — cleaning up")
                    self.isSyncing = false
                }
            case .connecting:
                self.logger.info("Connecting to: \(peerName)")
                self.connectionState = .connecting
            case .connected:
                self.logger.info("Connected to: \(peerName)")
                self.connectionState = .connected
                self.connectedPeerName = peerName
                self.lastError = nil
            @unknown default:
                self.logger.warning("Unknown session state for: \(peerName)")
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.handleReceivedData(data)
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Not used — we use data messages and resource transfers
    }

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Task { @MainActor in
            self.logger.info("Receiving resource: \(resourceName) from \(peerID.displayName)")
        }
    }

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard let localURL, error == nil else {
            Task { @MainActor in
                self.logger.error("Resource receive failed: \(error?.localizedDescription ?? "unknown")")
                self.lastError = "Receive failed: \(error?.localizedDescription ?? "unknown")"
            }
            return
        }

        do {
            let data = try Data(contentsOf: localURL)
            try? FileManager.default.removeItem(at: localURL)
            Task { @MainActor in
                self.handleReceivedData(data)
            }
        } catch {
            Task { @MainActor in
                self.logger.error("Failed to read received resource: \(error.localizedDescription)")
                self.lastError = "Read error: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate (iOS)

extension SyncService: MCNearbyServiceAdvertiserDelegate {

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitations from peers using our service type
        Task { @MainActor in
            self.logger.info("Received invitation from: \(peerID.displayName) — auto-accepting")
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.logger.error("Failed to start advertising: \(error.localizedDescription)")
            self.lastError = "Advertising failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (macOS)

extension SyncService: MCNearbyServiceBrowserDelegate {

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            self.logger.info("Discovered peer: \(peerID.displayName)")
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                self.discoveredPeers.append(peerID)
            }

            // Auto-connect to the first discovered peer if not already connected
            if self.connectionState == .disconnected {
                self.connectToPeer(peerID)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.logger.info("Lost peer: \(peerID.displayName)")
            self.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.logger.error("Failed to start browsing: \(error.localizedDescription)")
            self.lastError = "Browsing failed: \(error.localizedDescription)"
        }
    }
}
