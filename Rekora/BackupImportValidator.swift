import Foundation

struct BackupImportSummary: Equatable, Sendable {
    var snapshotID: UUID
    var createdAt: Date
    var schemaVersion: Int
    var appVersion: String
    var platform: String
    var songCount: Int
    var albumCount: Int
    var playlistCount: Int
    var playlistTrackCount: Int
    var playlistOrderWarningCount: Int
}

enum BackupImportValidationError: Error, Equatable {
    case cannotReadFile
    case fileTooLarge
    case notRekoraBackup
    case unsupportedSchemaVersion(Int)
    case invalidBackup

    var userMessage: String {
        switch self {
        case .cannotReadFile:
            "Rekora could not read that file. Try choosing another backup."
        case .fileTooLarge:
            "That file is too large for Rekora to check safely. Try choosing a smaller backup."
        case .notRekoraBackup:
            "Rekora could not read that backup. Try choosing another backup file."
        case .unsupportedSchemaVersion:
            "That backup was created with a newer version of Rekora. Update Rekora and try again."
        case .invalidBackup:
            "Rekora found that backup, but some details are missing or damaged."
        }
    }
}

enum BackupImportValidator {
    static let maxImportFileSizeBytes: Int64 = 50 * 1024 * 1024

    static func validate(
        fileURL: URL,
        maxFileSizeBytes: Int64 = maxImportFileSizeBytes
    ) throws -> BackupImportSummary {
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try validateFileSize(fileURL: fileURL, maxFileSizeBytes: maxFileSizeBytes)
            return try validate(data: Data(contentsOf: fileURL))
        } catch let error as BackupImportValidationError {
            throw error
        } catch {
            throw BackupImportValidationError.cannotReadFile
        }
    }

    static func validate(data: Data) throws -> BackupImportSummary {
        let decoder = BackupSnapshotCoding.makeDecoder()

        let envelope: SchemaEnvelope
        do {
            envelope = try decoder.decode(SchemaEnvelope.self, from: data)
        } catch {
            throw BackupImportValidationError.notRekoraBackup
        }

        if envelope.hasFormatMarker, envelope.format != BackupSnapshot.formatIdentifier {
            throw BackupImportValidationError.notRekoraBackup
        }

        guard envelope.schemaVersion == BackupSnapshot.currentSchemaVersion else {
            throw BackupImportValidationError.unsupportedSchemaVersion(envelope.schemaVersion)
        }

        let snapshot: BackupSnapshot
        do {
            snapshot = try decoder.decode(BackupSnapshot.self, from: data)
        } catch {
            throw BackupImportValidationError.invalidBackup
        }

        return BackupImportSummary(snapshot: snapshot)
    }

    private static func validateFileSize(
        fileURL: URL,
        maxFileSizeBytes: Int64
    ) throws {
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize else {
            throw BackupImportValidationError.cannotReadFile
        }

        guard Int64(fileSize) <= maxFileSizeBytes else {
            throw BackupImportValidationError.fileTooLarge
        }
    }

    private struct SchemaEnvelope: Decodable {
        var format: String?
        var hasFormatMarker: Bool
        var schemaVersion: Int

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.hasFormatMarker = container.contains(.format)
            if hasFormatMarker {
                guard try !container.decodeNil(forKey: .format) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .format,
                        in: container,
                        debugDescription: "Backup format marker cannot be null."
                    )
                }
                self.format = try container.decode(String.self, forKey: .format)
            } else {
                self.format = nil
            }
            self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        }

        private enum CodingKeys: String, CodingKey {
            case format
            case schemaVersion
        }
    }
}

extension BackupImportSummary {
    init(snapshot: BackupSnapshot) {
        self.snapshotID = snapshot.snapshotID
        self.createdAt = snapshot.createdAt
        self.schemaVersion = snapshot.schemaVersion
        self.appVersion = snapshot.source.appVersion
        self.platform = snapshot.source.platform
        self.songCount = snapshot.songs.count
        self.albumCount = snapshot.albums.count
        self.playlistCount = snapshot.playlists.count
        self.playlistTrackCount = snapshot.playlists.reduce(0) { count, playlist in
            count + playlist.tracks.count
        }
        self.playlistOrderWarningCount = SnapshotManifest.playlistOrderWarningCount(in: snapshot)
    }
}
