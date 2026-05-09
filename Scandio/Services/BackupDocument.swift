import SwiftUI
import UniformTypeIdentifiers

/// FileDocument wrapper for the Scandio backup format (.scandiobackup).
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.scandioBackup] }
    static var writableContentTypes: [UTType] { [.scandioBackup] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
