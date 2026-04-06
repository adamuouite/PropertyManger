import Foundation
import AppKit
import UniformTypeIdentifiers

struct PDFManager {

    // MARK: - Folder paths

    /// Root folder: ~/Documents/PropertyManager/Contracts/
    static var contractsFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("PropertyManager/Contracts", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Root folder: ~/Documents/PropertyManager/TenantDocs/
    static var tenantDocsFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("PropertyManager/TenantDocs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Root folder: ~/Documents/PropertyManager/Reports/
    static var reportsFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let folder = docs.appendingPathComponent("PropertyManager/Reports", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    // MARK: - Contract PDF

    /// Opens an NSOpenPanel and returns the chosen PDF URL (nil if cancelled)
    static func pickPDF() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select Contract PDF"
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose the signed contract PDF to attach"
        panel.prompt = "Attach"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Copies the source PDF into the contracts folder.
    /// Returns the stored filename (not full path) so it stays portable.
    @discardableResult
    static func attachPDF(from source: URL, contractNumber: String) throws -> String {
        let sanitized = contractNumber.replacingOccurrences(of: "/", with: "-")
                                      .replacingOccurrences(of: ":", with: "-")
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let unique = UUID().uuidString.prefix(8)
        let filename = "\(sanitized)_\(timestamp)_\(unique).pdf"
        let destination = contractsFolder.appendingPathComponent(filename)

        // Remove old file if exists
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        return filename
    }

    /// Full URL for a stored filename
    static func url(for filename: String) -> URL {
        contractsFolder.appendingPathComponent(filename)
    }

    /// Opens the PDF in Preview (or default PDF viewer)
    static func open(filename: String) {
        let url = Self.url(for: filename)
        NSWorkspace.shared.open(url)
    }

    /// Reveals the PDF in Finder
    static func revealInFinder(filename: String) {
        let url = Self.url(for: filename)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Deletes the stored PDF file
    static func delete(filename: String) {
        let url = Self.url(for: filename)
        try? FileManager.default.removeItem(at: url)
    }

    /// Returns file size string for display
    static func fileSize(filename: String) -> String {
        let url = Self.url(for: filename)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else { return "Unknown size" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// Returns true if the file actually exists on disk
    static func exists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: url(for: filename).path)
    }

    // MARK: - Tenant ID Documents

    /// Opens an NSOpenPanel for images and PDFs (tenant ID documents)
    static func pickIDDocument() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Select ID Document"
        var types: [UTType] = [.pdf, .png, .jpeg, .tiff, .bmp, .heic]
        if let webp = UTType("org.webmproject.webp") { types.append(webp) }
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "Choose an ID document (image or PDF) to attach"
        panel.prompt = "Attach"
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Copies an ID document into TenantDocs. Returns the stored filename.
    @discardableResult
    static func attachIDDocument(from source: URL, tenantName: String) throws -> String {
        let sanitized = tenantName.replacingOccurrences(of: "/", with: "-")
                                  .replacingOccurrences(of: ":", with: "-")
                                  .replacingOccurrences(of: " ", with: "_")
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let unique = UUID().uuidString.prefix(8)
        let ext = source.pathExtension.lowercased()
        let filename = "ID_\(sanitized)_\(timestamp)_\(unique).\(ext)"
        let destination = tenantDocsFolder.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        return filename
    }

    /// Full URL for a tenant document filename
    static func tenantDocURL(for filename: String) -> URL {
        tenantDocsFolder.appendingPathComponent(filename)
    }

    /// Opens a tenant document in its default app
    static func openTenantDoc(filename: String) {
        NSWorkspace.shared.open(tenantDocURL(for: filename))
    }

    /// Reveals tenant doc in Finder
    static func revealTenantDocInFinder(filename: String) {
        NSWorkspace.shared.activateFileViewerSelecting([tenantDocURL(for: filename)])
    }

    /// Deletes a tenant document
    static func deleteTenantDoc(filename: String) {
        try? FileManager.default.removeItem(at: tenantDocURL(for: filename))
    }

    /// File size for tenant document
    static func tenantDocFileSize(filename: String) -> String {
        let url = tenantDocURL(for: filename)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int else { return "Unknown size" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    /// Checks existence of tenant document
    static func tenantDocExists(filename: String) -> Bool {
        FileManager.default.fileExists(atPath: tenantDocURL(for: filename).path)
    }

    /// Returns true if the filename is an image (not PDF)
    static func isImage(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return ["png", "jpg", "jpeg", "tiff", "tif", "bmp", "heic", "webp"].contains(ext)
    }
}
