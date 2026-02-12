import Foundation

// MARK: - Sync Message Protocol

/// Messages exchanged between iOS and macOS over Multipeer Connectivity.
enum SyncMessage: Codable {
    /// macOS → iOS: Request health data for specific dates
    case requestData(dates: [Date])

    /// macOS → iOS: Request ALL available health data (all time)
    case requestAllData

    /// iOS → macOS: Health data payload
    case healthData(SyncPayload)

    /// iOS → macOS: Progress update during a large sync (e.g., all-time)
    case syncProgress(SyncProgressInfo)

    /// Keepalive / connection test
    case ping

    /// Response to ping
    case pong
}

// MARK: - Sync Progress Info

/// Progress information sent from iOS to macOS during large syncs.
struct SyncProgressInfo: Codable {
    /// Total number of dates being processed
    let totalDays: Int

    /// Number of dates processed so far
    let processedDays: Int

    /// Number of dates in this batch that had data
    let recordsInBatch: Int

    /// Whether this is the final progress update (sync complete)
    let isComplete: Bool

    /// Optional message for display
    let message: String?

    var fractionComplete: Double {
        guard totalDays > 0 else { return 0 }
        return Double(processedDays) / Double(totalDays)
    }
}

// MARK: - Sync Payload

/// Container for health data sent from iOS to macOS.
struct SyncPayload: Codable {
    /// Name of the source device (e.g., "Cody's iPhone")
    let deviceName: String

    /// When this sync payload was created
    let syncTimestamp: Date

    /// One HealthData record per date
    let healthRecords: [HealthData]
}

// MARK: - Sync Metadata

/// Metadata stored alongside cached health data on macOS.
struct SyncMetadata: Codable {
    /// Last successful sync timestamp
    var lastSyncDate: Date?

    /// Name of the device that sent the data
    var sourceDeviceName: String?

    /// Total number of date records stored locally
    var recordCount: Int = 0

    /// Dates that have been synced
    var syncedDates: [Date] = []
}
