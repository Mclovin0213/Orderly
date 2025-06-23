// Services/FileSystemService.swift
import Foundation
import AppKit // For NSOpenPanel

class FileSystemService {
    func selectFolder(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select Folder to Organize"

        openPanel.begin { response in
            if response == .OK {
                completion(openPanel.url)
            } else {
                completion(nil)
            }
        }
    }

    func listFiles(in folderURL: URL) -> [FileItem] {
        let fileManager = FileManager.default
        var files: [FileItem] = []
        do {
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)
            for url in contents {
                var isDirectory: ObjCBool = false
                fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
                files.append(FileItem(name: url.lastPathComponent, url: url, isDirectory: isDirectory.boolValue))
            }
        } catch {
            print("Error listing contents of directory \(folderURL.path): \(error.localizedDescription)")
            // Optionally, return an error or an empty array with a status
        }
        return files.sorted { $0.name.lowercased() < $1.name.lowercased() } // Sort for consistency
    }
func applyOrganizationPlan(plan: [ProposedFileSystemChange], baseFolderURL: URL) throws -> UndoBatch {
                let fileManager = FileManager.default
                var undoBatch = UndoBatch()

                for change in plan where change.isApproved { // Only process approved changes
                    let targetFolderName = change.folderName
                    let targetFolderURL = baseFolderURL.appendingPathComponent(targetFolderName, isDirectory: true)

                    if change.isNewFolder {
                        // Check if it's genuinely new or LLM hallucinated 'isNewFolder' for an existing one
                        var isDir: ObjCBool = false
                        if !fileManager.fileExists(atPath: targetFolderURL.path, isDirectory: &isDir) || !isDir.boolValue {
                            try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true, attributes: nil)
                            undoBatch.directoryCreations.append(DirectoryCreationRecord(createdDirectoryURL: targetFolderURL))
                        }
                        // If it existed but was marked new, we just use it.
                    } else {
                        // If it's an existing folder, ensure it actually exists
                        var isDir: ObjCBool = false
                        if !fileManager.fileExists(atPath: targetFolderURL.path, isDirectory: &isDir) || !isDir.boolValue {
                            // LLM might be wrong, or user deleted it. For now, try creating it.
                            // Or, throw an error / skip this change.
                            print("Warning: Folder '\(targetFolderName)' marked as existing but not found. Attempting to create.")
                            try fileManager.createDirectory(at: targetFolderURL, withIntermediateDirectories: true, attributes: nil)
                            undoBatch.directoryCreations.append(DirectoryCreationRecord(createdDirectoryURL: targetFolderURL))
                        }
                    }

                    for fileName in change.filesToMove {
                        let originalFileURL = baseFolderURL.appendingPathComponent(fileName) // Assuming files are at the root of baseFolderURL
                        let newFileURL = targetFolderURL.appendingPathComponent(fileName)

                        // Check if original file exists before moving
                        if fileManager.fileExists(atPath: originalFileURL.path) {
                            try fileManager.moveItem(at: originalFileURL, to: newFileURL)
                            undoBatch.fileMoves.append(FileOperationRecord(originalURL: originalFileURL, newURL: newFileURL))
                        } else {
                            print("Warning: File '\(fileName)' not found at '\(originalFileURL.path)', skipping move.")
                            // Optionally, collect these skipped files to inform the user
                        }
                    }
                }
                return undoBatch
            }

            func undoOrganizationBatch(batch: UndoBatch) throws {
                let fileManager = FileManager.default

                // Undo file moves first (move them back) - in reverse order of move? Not strictly necessary.
                for record in batch.fileMoves.reversed() { // Reverse might be safer if files were renamed/moved over each other
                    // Ensure the destination (original location's parent) exists
                    let originalParentDir = record.originalURL.deletingLastPathComponent()
                    if !fileManager.fileExists(atPath: originalParentDir.path) {
                        try fileManager.createDirectory(at: originalParentDir, withIntermediateDirectories: true, attributes: nil)
                    }
                    // Check if file to be moved back actually exists at newURL
                    if fileManager.fileExists(atPath: record.newURL.path) {
                         try fileManager.moveItem(at: record.newURL, to: record.originalURL)
                    } else {
                        print("Warning: File to undo '\(record.newURL.path)' not found. Skipping undo for this file.")
                    }
                }

                // Optionally, attempt to remove created directories IF THEY ARE EMPTY
                // This is trickier and riskier. For MVP, you might skip auto-deletion.
                for record in batch.directoryCreations.reversed() { // Process deeper folders first
                    do {
                        // Check if directory is empty before deleting
                        let contents = try fileManager.contentsOfDirectory(at: record.createdDirectoryURL, includingPropertiesForKeys: nil)
                        if contents.isEmpty {
                            try fileManager.removeItem(at: record.createdDirectoryURL)
                        } else {
                            print("Info: Directory '\(record.createdDirectoryURL.path)' was not empty, not removed during undo.")
                        }
                    } catch {
                        // Handle error (e.g., directory not found, permissions error)
                        print("Warning: Could not remove directory '\(record.createdDirectoryURL.path)' during undo: \(error.localizedDescription)")
                    }
                }
            }
}