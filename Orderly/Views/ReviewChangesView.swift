// Views/ReviewChangesView.swift
import SwiftUI

struct ReviewChangesView: View {
    @Binding var proposedChanges: [ProposedFileSystemChange] // Use Binding to allow modifications
    // Or pass in a dedicated ViewModel for this view if it gets complex

    var body: some View {
        VStack(alignment: .leading) {
            Text("Review Proposed Changes")
                .font(.title2)
                .padding(.bottom)

            if proposedChanges.isEmpty {
                Text("No organization plan proposed yet, or an error occurred.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List {
                    ForEach($proposedChanges) { $change in // Use $ for binding
                        DisclosureGroup(
                            isExpanded: .constant(true), // Default to expanded, or manage state
                            content: {
                                ForEach(change.filesToMove, id: \.self) { fileName in
                                    HStack {
                                        Image(systemName: "doc")
                                        Text(fileName)
                                        Spacer()
                                        // Checkbox for individual file approval (more advanced)
                                        // For now, approve/reject whole folder proposal
                                    }
                                    .padding(.leading)
                                }
                            },
                            label: {
                                HStack {
                                    Image(systemName: change.isNewFolder ? "folder.badge.plus" : "folder")
                                    Text(change.folderName)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Toggle("Approve", isOn: $change.isApproved) // Directly modifies the model
                                        .labelsHidden() // If you want just the toggle
                                }
                            }
                        )
                    }
                }
            }
            // Buttons for "Approve All", "Reject All" (Week 7)
        }
        .padding()
    }
}

// Preview needs a sample
#Preview {
    struct PreviewWrapper: View {
        @State var sampleChanges: [ProposedFileSystemChange] = [
            ProposedFileSystemChange(folderName: "Holiday Snaps 2024", filesToMove: ["IMG_001.jpg", "IMG_002.png"], isNewFolder: true, isApproved: true),
            ProposedFileSystemChange(folderName: "Old Project/Docs", filesToMove: ["archive_notes.txt"], isNewFolder: false, isApproved: false)
        ]
        var body: some View {
            ReviewChangesView(proposedChanges: $sampleChanges)
        }
    }
    return PreviewWrapper()
}