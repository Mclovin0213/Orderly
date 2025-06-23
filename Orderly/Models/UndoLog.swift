// Models/UndoLog.swift
import Foundation

struct FileOperationRecord: Codable, Identifiable {
    let id = UUID()
    var originalURL: URL
    var newURL: URL // Where it was moved TO
}

// Could also log created directories if you want to attempt to remove them on undo
struct DirectoryCreationRecord: Codable, Identifiable {
    let id = UUID()
    var createdDirectoryURL: URL
}

// A single undo batch
struct UndoBatch: Codable {
    let timestamp: Date = Date()
    var fileMoves: [FileOperationRecord] = []
    var directoryCreations: [DirectoryCreationRecord] = []
}