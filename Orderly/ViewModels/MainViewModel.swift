// ViewModels/MainViewModel.swift
import SwiftUI
import Combine // For @Published

class MainViewModel: ObservableObject {
    @Published var selectedFolderPath: String?
    @Published var selectedFolderURL: URL?
    @Published var files: [FileItem] = []
    @Published var isLoadingFiles: Bool = false
    @Published var ollamaStatus: OllamaStatus = .unknown // For Week 4
    @Published var ollamaRawResponse: String = "" // For Week 4
    @Published var proposedChanges: [ProposedFileSystemChange] = []
    @Published var lastUndoBatch: UndoBatch?
    @Published var isApplyingChanges: Bool = false // For progress indicator

    private let fileSystemService = FileSystemService()
    private let ollamaAPIService = OllamaAPIService()
    @Published var selectedOllamaModel: String = "qwen3:8b" // Default model, make this selectable later

    func openFolderSelection() {
        fileSystemService.selectFolder { [weak self] url in
            guard let self = self, let url = url else { return }
            // Store security-scoped bookmark here if aiming for persistent access
            // For now, just direct access
            DispatchQueue.main.async {
                self.selectedFolderURL = url
                self.selectedFolderPath = url.path
                self.loadFilesFromSelectedFolder()
            }
        }
    }

    func loadFilesFromSelectedFolder() {
        guard let url = selectedFolderURL else { return }
        isLoadingFiles = true
        // Simulate a slight delay if needed for UI responsiveness on large folders
        DispatchQueue.global(qos: .userInitiated).async {
            let listedFiles = self.fileSystemService.listFiles(in: url)
            DispatchQueue.main.async {
                self.files = listedFiles
                self.isLoadingFiles = false
            }
        }
    }

    // Placeholder for Week 4
    func checkOllamaStatus() {
        ollamaStatus = .checking
        ollamaAPIService.checkAvailability { [weak self] available, error in
            DispatchQueue.main.async {
                if available {
                    self?.ollamaStatus = .available
                    // Optionally, fetch available models here too for a dropdown
                } else {
                    self?.ollamaStatus = .unavailable
                    self?.ollamaRawResponse = "Ollama connection failed: \(error?.localizedDescription ?? "Unknown error")"
                    print("Ollama unavailable: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }

    func proposeOrganizationPlan() {
        guard let folderURL = selectedFolderURL, !files.isEmpty else {
            ollamaRawResponse = "No folder selected or folder is empty."
            return
        }
        guard ollamaStatus == .available else {
            ollamaRawResponse = "Ollama is not available."
            return
        }

        let fileNamesOnly = files.filter { !$0.isDirectory }.map { $0.name }
        let existingSubfolderNames = files.filter { $0.isDirectory }.map { $0.name }

        if fileNamesOnly.isEmpty {
            ollamaRawResponse = "No files (non-directories) to organize."
            return
        }

        ollamaRawResponse = "Requesting structured plan from Ollama (\(selectedOllamaModel))..."
        isLoadingFiles = true // Or a new @Published var isLoadingPlan
        proposedChanges = [] // Clear previous plan

        ollamaAPIService.generateStructuredOrganizationPlan(
            fileNames: fileNamesOnly,
            existingFolderStructure: existingSubfolderNames.isEmpty ? nil : existingSubfolderNames,
            modelName: selectedOllamaModel
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingFiles = false
                switch result {
                case .success(let plan):
                    self?.proposedChanges = plan
                    self?.ollamaRawResponse = "Successfully received structured plan. See Review Panel." // Or JSON string for debug
                case .failure(let error):
                    self?.proposedChanges = []
                    self?.ollamaRawResponse = "Error getting structured plan: \(error.localizedDescription)"
                }
            }
        }
    }

    func applyApprovedChanges() {
        guard let folderURL = selectedFolderURL else { return }
        let approvedChanges = proposedChanges.filter { $0.isApproved }
        if approvedChanges.isEmpty {
            ollamaRawResponse = "No changes approved." // Or a more user-friendly message area
            return
        }

        isApplyingChanges = true
        ollamaRawResponse = "Applying changes..." // Or use a status bar

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let batch = try self.fileSystemService.applyOrganizationPlan(plan: approvedChanges, baseFolderURL: folderURL)
                DispatchQueue.main.async {
                    self.lastUndoBatch = batch
                    self.proposedChanges = [] // Clear the plan
                    self.loadFilesFromSelectedFolder() // Refresh file list
                    self.ollamaRawResponse = "Organization applied successfully! \(batch.fileMoves.count) files moved, \(batch.directoryCreations.count) new folders created."
                    self.isApplyingChanges = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.ollamaRawResponse = "Error applying changes: \(error.localizedDescription)"
                    // Potentially, don't clear proposedChanges if it fails, so user can retry/adjust
                    self.isApplyingChanges = false
                }
            }
        }
    }

    func undoLastOrganization() {
        guard let batchToUndo = lastUndoBatch else {
            ollamaRawResponse = "No previous organization batch to undo."
            return
        }

        isApplyingChanges = true // Reuse for undo progress
        ollamaRawResponse = "Undoing last organization..."

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.fileSystemService.undoOrganizationBatch(batch: batchToUndo)
                DispatchQueue.main.async {
                    self.lastUndoBatch = nil // Clear the undo batch
                    self.loadFilesFromSelectedFolder() // Refresh
                    self.ollamaRawResponse = "Undo successful."
                    self.isApplyingChanges = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.ollamaRawResponse = "Error undoing changes: \(error.localizedDescription)"
                    // Potentially keep lastUndoBatch if undo fails partially? Complex.
                    self.isApplyingChanges = false
                }
            }
        }
    }
}

// Enum for Ollama status (add to MainViewModel or a separate file)
enum OllamaStatus {
    case unknown, available, unavailable, checking
}
