//
//  AdvancedExportSettings.swift
//  Health.md
//
//  Created by Claude on 2026-01-13.
//

import Foundation
import Combine

enum ExportFormat: String, CaseIterable, Codable {
    case markdown = "Markdown"
    case obsidianBases = "Obsidian Bases"
    case json = "JSON"
    case csv = "CSV"

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .obsidianBases: return "md"
        case .json: return "json"
        case .csv: return "csv"
        }
    }
}

struct DataTypeSelection: Codable {
    var sleep: Bool = true
    var activity: Bool = true
    var heart: Bool = true
    var vitals: Bool = true
    var body: Bool = true
    var nutrition: Bool = true
    var mindfulness: Bool = true
    var mobility: Bool = true
    var hearing: Bool = true
    var workouts: Bool = true

    var hasAnySelected: Bool {
        sleep || activity || heart || vitals || body || nutrition ||
        mindfulness || mobility || hearing || workouts
    }

    /// Returns the count of enabled data types
    var enabledCount: Int {
        [sleep, activity, heart, vitals, body, nutrition, mindfulness, mobility, hearing, workouts]
            .filter { $0 }.count
    }

    /// Select all data types
    mutating func selectAll() {
        sleep = true
        activity = true
        heart = true
        vitals = true
        body = true
        nutrition = true
        mindfulness = true
        mobility = true
        hearing = true
        workouts = true
    }

    /// Deselect all data types
    mutating func deselectAll() {
        sleep = false
        activity = false
        heart = false
        vitals = false
        body = false
        nutrition = false
        mindfulness = false
        mobility = false
        hearing = false
        workouts = false
    }
}

class AdvancedExportSettings: ObservableObject {
    @Published var dataTypes: DataTypeSelection {
        didSet { save() }
    }

    @Published var exportFormat: ExportFormat {
        didSet { save() }
    }

    @Published var includeMetadata: Bool {
        didSet { save() }
    }

    @Published var groupByCategory: Bool {
        didSet { save() }
    }

    @Published var filenameFormat: String {
        didSet { save() }
    }

    @Published var folderStructure: String {
        didSet { save() }
    }

    private let userDefaults = UserDefaults.standard
    private let dataTypesKey = "advancedExportSettings.dataTypes"
    private let formatKey = "advancedExportSettings.format"
    private let metadataKey = "advancedExportSettings.metadata"
    private let groupByCategoryKey = "advancedExportSettings.groupByCategory"
    private let filenameFormatKey = "advancedExportSettings.filenameFormat"
    private let folderStructureKey = "advancedExportSettings.folderStructure"

    static let defaultFilenameFormat = "{date}"
    static let defaultFolderStructure = ""  // Empty = flat structure

    /// Formats a filename using the current format template and a given date
    /// Supported placeholders: {date}, {year}, {month}, {day}, {weekday}, {monthName}
    func formatFilename(for date: Date) -> String {
        return applyDatePlaceholders(to: filenameFormat, for: date)
    }

    /// Formats the folder structure path using the current template and a given date
    /// Returns nil if folder structure is empty (flat structure)
    /// Supported placeholders: {year}, {month}, {day}, {weekday}, {monthName}
    func formatFolderPath(for date: Date) -> String? {
        guard !folderStructure.isEmpty else { return nil }
        return applyDatePlaceholders(to: folderStructure, for: date)
    }

    /// Common method to apply date placeholders to a template string
    private func applyDatePlaceholders(to template: String, for date: Date) -> String {
        let dateFormatter = DateFormatter()
        var result = template

        // {date} -> yyyy-MM-dd
        dateFormatter.dateFormat = "yyyy-MM-dd"
        result = result.replacingOccurrences(of: "{date}", with: dateFormatter.string(from: date))

        // {year} -> yyyy
        dateFormatter.dateFormat = "yyyy"
        result = result.replacingOccurrences(of: "{year}", with: dateFormatter.string(from: date))

        // {month} -> MM
        dateFormatter.dateFormat = "MM"
        result = result.replacingOccurrences(of: "{month}", with: dateFormatter.string(from: date))

        // {day} -> dd
        dateFormatter.dateFormat = "dd"
        result = result.replacingOccurrences(of: "{day}", with: dateFormatter.string(from: date))

        // {weekday} -> Monday, Tuesday, etc.
        dateFormatter.dateFormat = "EEEE"
        result = result.replacingOccurrences(of: "{weekday}", with: dateFormatter.string(from: date))

        // {monthName} -> January, February, etc.
        dateFormatter.dateFormat = "MMMM"
        result = result.replacingOccurrences(of: "{monthName}", with: dateFormatter.string(from: date))

        return result
    }

    init() {
        // Load data types
        if let data = userDefaults.data(forKey: dataTypesKey),
           let decoded = try? JSONDecoder().decode(DataTypeSelection.self, from: data) {
            self.dataTypes = decoded
        } else {
            self.dataTypes = DataTypeSelection()
        }

        // Load format
        if let formatString = userDefaults.string(forKey: formatKey),
           let format = ExportFormat(rawValue: formatString) {
            self.exportFormat = format
        } else {
            self.exportFormat = .markdown
        }

        // Load metadata option
        self.includeMetadata = userDefaults.bool(forKey: metadataKey)
        if userDefaults.object(forKey: metadataKey) == nil {
            self.includeMetadata = true // Default to true
        }

        // Load group by category option
        self.groupByCategory = userDefaults.bool(forKey: groupByCategoryKey)
        if userDefaults.object(forKey: groupByCategoryKey) == nil {
            self.groupByCategory = true // Default to true
        }

        // Load filename format
        if let savedFormat = userDefaults.string(forKey: filenameFormatKey) {
            self.filenameFormat = savedFormat
        } else {
            self.filenameFormat = Self.defaultFilenameFormat
        }

        // Load folder structure
        if let savedStructure = userDefaults.string(forKey: folderStructureKey) {
            self.folderStructure = savedStructure
        } else {
            self.folderStructure = Self.defaultFolderStructure
        }
    }

    private func save() {
        // Save data types
        if let encoded = try? JSONEncoder().encode(dataTypes) {
            userDefaults.set(encoded, forKey: dataTypesKey)
        }

        // Save format
        userDefaults.set(exportFormat.rawValue, forKey: formatKey)

        // Save metadata option
        userDefaults.set(includeMetadata, forKey: metadataKey)

        // Save group by category option
        userDefaults.set(groupByCategory, forKey: groupByCategoryKey)

        // Save filename format
        userDefaults.set(filenameFormat, forKey: filenameFormatKey)

        // Save folder structure
        userDefaults.set(folderStructure, forKey: folderStructureKey)
    }

    func reset() {
        dataTypes = DataTypeSelection()
        exportFormat = .markdown
        includeMetadata = true
        groupByCategory = true
        filenameFormat = Self.defaultFilenameFormat
        folderStructure = Self.defaultFolderStructure
    }
}
