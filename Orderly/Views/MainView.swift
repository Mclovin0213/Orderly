// Views/MainView.swift
import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    var body: some View {
        HSplitView {
            
            VStack(alignment: .leading) {
                HStack {
                    Button("Select Folder") {
                        viewModel.openFolderSelection()
                    }
                    
                    Circle()
                        .frame(width: 10, height: 10)
                        .foregroundColor(ollamaStatusColor())
                    Text(ollamaStatusText())
                        .font(.caption)
                }
                .padding([.top, .leading, .trailing])


                if let path = viewModel.selectedFolderPath {
                    Text("Organizing: \(path)")
                        .font(.headline)
                        .padding(.horizontal)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No folder selected.")
                        .font(.headline)
                        .padding(.horizontal)
                }

                if viewModel.isLoadingFiles {
                    ProgressView()
                        .padding()
                } else {
                    List(viewModel.files) { file in
                        HStack {
                            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                            Text(file.name)
                        }
                    }
                    .frame(minHeight: 200)
                }

                Button("Organize This Folder (Raw Output)") {
                    viewModel.proposeOrganizationPlan()
                }
                .disabled(viewModel.selectedFolderURL == nil || viewModel.ollamaStatus != .available)
                .padding()

                Spacer() // Pushes content up
            }
            .frame(minWidth: 300, idealWidth: 400) // Left panel width

            // Right Panel: Review Area (Placeholder for now)
            VStack {
                Text("Review Proposed Changes")
                    .font(.title2)
                    .padding()
                // This will show raw response in Week 4
                ScrollView {
                    ReviewChangesView(proposedChanges: $viewModel.proposedChanges)
                }
                .padding()
                
            HStack {
                Button("Apply Approved Changes") {
                    viewModel.applyApprovedChanges()
                }
                .disabled(viewModel.proposedChanges.filter { $0.isApproved }.isEmpty || viewModel.isApplyingChanges)

                Button("Undo Last Organization") {
                    viewModel.undoLastOrganization()
                }
                .disabled(viewModel.lastUndoBatch == nil || viewModel.isApplyingChanges)
            }
            .padding()

        if viewModel.isApplyingChanges {
            ProgressView().padding(.bottom)
        }
                Spacer()
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 700, minHeight: 400)
        .onAppear {
            viewModel.checkOllamaStatus()
        }
    }

    // Helper for Ollama Status UI (Week 4)
    private func ollamaStatusColor() -> Color {
        switch viewModel.ollamaStatus {
        case .unknown: return .gray
        case .available: return .green
        case .unavailable: return .red
        case .checking: return .yellow
        }
    }

    private func ollamaStatusText() -> String {
        switch viewModel.ollamaStatus {
        case .unknown: return "Ollama: Unknown"
        case .available: return "Ollama: Ready"
        case .unavailable: return "Ollama: Unavailable/Error"
        case .checking: return "Ollama: Checking..."
        }
    }
}

#Preview {
    MainView()
}
