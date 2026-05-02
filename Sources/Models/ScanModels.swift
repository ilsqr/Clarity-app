import Foundation

struct ActiveAlert: Identifiable {
    enum Kind {
        case confirmClean
        case cleanupDone
    }

    let id = UUID()
    let kind: Kind
    let message: String?
}

struct DiskStats {
    let freeBytes: Int64
    let totalBytes: Int64

    static let empty = DiskStats(freeBytes: 0, totalBytes: 0)

    var freeRatio: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }

    var freePercentText: String {
        let percent = Int((freeRatio * 100).rounded())
        return totalBytes > 0 ? "\(percent)%" : "--"
    }

    var totalText: String {
        guard totalBytes > 0 else { return "Drive size unknown" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: totalBytes)) drive"
    }
}

struct ScanItem: Identifiable {
    let id = UUID()
    let title: String
    let url: URL

    static func defaultItems() -> [ScanItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        return [
            ScanItem(title: "User Caches", url: home.appendingPathComponent("Library/Caches")),
            ScanItem(title: "System Logs", url: URL(fileURLWithPath: "/Library/Logs")),
            ScanItem(title: "User Logs", url: home.appendingPathComponent("Library/Logs")),
            ScanItem(title: "Downloads", url: home.appendingPathComponent("Downloads")),
            ScanItem(title: "Xcode DerivedData", url: home.appendingPathComponent("Library/Developer/Xcode/DerivedData")),
            ScanItem(title: "Trash", url: home.appendingPathComponent(".Trash"))
        ]
    }
}

struct ScanResult: Identifiable {
    let id = UUID()
    let item: ScanItem
    let bytes: Int64
    let subcategories: [ScanSubcategory]

    var allFileIds: [UUID] {
        subcategories.flatMap { $0.files.map { $0.id } }
    }
}

struct ScanSubcategory: Identifiable {
    let id = UUID()
    let name: String
    let files: [ScanFile]

    var totalBytes: Int64 {
        files.reduce(0) { $0 + $1.bytes }
    }
}

struct ScanFile: Identifiable {
    let id = UUID()
    let url: URL
    let bytes: Int64
}
