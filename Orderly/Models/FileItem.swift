// Models/FileItem.swift
import Foundation

struct FileItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: URL // Store the full URL for later operations
    let isDirectory: Bool // Good to know
    // Add other metadata later if needed (size, date, etc.)
}