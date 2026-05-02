import Foundation

struct DiskService {
    static func loadDiskStats() -> DiskStats {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: "/")
            let free = attributes[.systemFreeSize] as? Int64 ?? 0
            let total = attributes[.systemSize] as? Int64 ?? 0
            return DiskStats(freeBytes: free, totalBytes: total)
        } catch {
            return DiskStats.empty
        }
    }
}

struct ScanService {
    static func scanFiles(in url: URL) -> ([ScanSubcategory], Int64) {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ([], 0)
        }

        var filesBySub: [String: [ScanFile]] = [:]
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
            ), values.isRegularFile == true else {
                continue
            }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            total += size

            let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
            let parts = relativePath.split(separator: "/")
            let subName = parts.first.map(String.init) ?? "Root"
            let file = ScanFile(url: fileURL, bytes: size)
            filesBySub[subName, default: []].append(file)
        }

        let subcategories = filesBySub
            .map { ScanSubcategory(name: $0.key, files: $0.value) }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
        return (subcategories, total)
    }

    static func deleteFile(_ url: URL) -> Bool {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            return true
        }
        do {
            try fm.removeItem(at: url)
            return true
        } catch {
            return false
        }
    }
}
