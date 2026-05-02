import SwiftUI

struct ContentView: View {
    @State private var diskStats = DiskStats.empty
    @State private var isScanning = false
    @State private var scanProgress = 0.0
    @State private var scanStatus = "Ready to scan"
    @State private var scanResults: [ScanResult] = []
    @State private var scanToken = UUID()
    @State private var activeAlert: ActiveAlert?
    @State private var selectedFileIds: Set<UUID> = []
    @State private var gaugeProgress = 0.0
    @State private var isGaugeAnimating = false
    @State private var isCleaning = false
    @State private var cleaningDone = 0
    @State private var cleaningTotal = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.16, blue: 0.24),
                    Color(red: 0.07, green: 0.08, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                if scanProgress >= 1 && !isScanning {
                    Button("Clean") {
                        activeAlert = ActiveAlert(kind: .confirmClean, message: nil)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(scanResults.isEmpty)

                    if !scanResults.isEmpty {
                        GlassPanel(width: 560, height: 360) {
                            ResultsListView(results: scanResults, selectedFileIds: $selectedFileIds)
                        }
                    }
                } else {
                    GlassPanel(width: 360, height: 260) {
                        VStack(spacing: 10) {
                            ZStack {
                                PartialRing(progress: gaugeProgress, color: gaugeDisplayColor)
                                    .frame(width: 170, height: 170)

                                Text(diskStats.freePercentText)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            Text("Free Space")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))

                            Text(diskStats.totalText)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    Button(isScanning ? "Scanning..." : "Start Scan") {
                        startScan()
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isScanning)

                    Text(scanStatus)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }

            }
            .padding(32)
        }
        .frame(minWidth: 760, minHeight: 520)
        .onAppear {
            diskStats = DiskService.loadDiskStats()
            animateGauge()
        }
        .alert(item: $activeAlert) { alert in
            switch alert.kind {
            case .confirmClean:
                return Alert(
                    title: Text("Confirm Clean"),
                    message: Text("This will remove the scanned items. Review details before cleaning in a future step."),
                    primaryButton: .destructive(Text("Clean Now")) {
                        performCleanup()
                    },
                    secondaryButton: .cancel(Text("Cancel"))
                )
            case .cleanupDone:
                return Alert(
                    title: Text("Cleanup completed"),
                    message: Text(alert.message ?? ""),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .sheet(isPresented: $isCleaning) {
            CleaningProgressView(done: cleaningDone, total: cleaningTotal)
        }
    }

    private var gaugeDisplayColor: Color {
        let ratio = isGaugeAnimating ? gaugeProgress : diskStats.freeRatio
        return colorForRatio(ratio)
    }

    private func animateGauge() {
        isGaugeAnimating = true
        gaugeProgress = 1
        withAnimation(.easeInOut(duration: 0.6)) {
            gaugeProgress = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 1.0)) {
                gaugeProgress = diskStats.freeRatio
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                isGaugeAnimating = false
            }
        }
    }

    private func colorForRatio(_ ratio: Double) -> Color {
        if ratio >= 0.6 {
            return Color(red: 0.4, green: 0.9, blue: 0.8)
        }
        if ratio >= 0.4 {
            return Color(red: 0.95, green: 0.78, blue: 0.2)
        }
        return Color(red: 0.95, green: 0.35, blue: 0.3)
    }

    private func startScan() {
        guard !isScanning else { return }
        stopScan()
        isScanning = true
        scanProgress = 0
        scanStatus = "Scanning system..."
        scanResults = []
        activeAlert = nil
        selectedFileIds = []

        let items = ScanItem.defaultItems()
        let totalCount = Double(items.count)
        let currentToken = UUID()
        scanToken = currentToken

        DispatchQueue.global(qos: .userInitiated).async {
            for (index, item) in items.enumerated() {
                let shouldContinue = DispatchQueue.main.sync { isScanning && scanToken == currentToken }
                if !shouldContinue {
                    return
                }
                let (subcategories, size) = ScanService.scanFiles(in: item.url)
                DispatchQueue.main.async {
                    if scanToken != currentToken {
                        return
                    }
                    scanResults.append(ScanResult(item: item, bytes: size, subcategories: subcategories))
                    scanProgress = min(1, Double(index + 1) / max(1, totalCount))
                    scanStatus = "Scanning \(item.title)\(scanDots(for: index))"
                }
            }

            DispatchQueue.main.async {
                if scanToken != currentToken {
                    return
                }
                scanProgress = 1
                scanStatus = "Scan complete"
                isScanning = false
                selectedFileIds = Set(scanResults.flatMap { $0.allFileIds })
            }
        }
    }

    private func stopScan() {
        if isScanning {
            scanStatus = "Scan cancelled"
        }
        isScanning = false
        scanToken = UUID()
    }

    private func performCleanup() {
        guard !isCleaning else { return }
        let filesToDelete = collectSelectedFiles()
        cleaningTotal = filesToDelete.count
        cleaningDone = 0
        isCleaning = true

        DispatchQueue.global(qos: .userInitiated).async {
            var totalRemoved: Int64 = 0
            var failedUrls: [URL] = []
            var deletedIds: Set<UUID> = []
            var failedIds: Set<UUID> = []

            for file in filesToDelete {
                if ScanService.deleteFile(file.url) {
                    totalRemoved += file.bytes
                    deletedIds.insert(file.id)
                } else {
                    failedUrls.append(file.url)
                    failedIds.insert(file.id)
                }

                DispatchQueue.main.async {
                    cleaningDone += 1
                }
            }

            DispatchQueue.main.async {
                isCleaning = false
                applyCleanupResults(deletedIds: deletedIds, failedIds: failedIds)
                showCleanupAlert(totalRemoved: totalRemoved, failedUrls: failedUrls)
            }
        }
    }

    private func collectSelectedFiles() -> [ScanFile] {
        var files: [ScanFile] = []
        for result in scanResults {
            for sub in result.subcategories {
                for file in sub.files where selectedFileIds.contains(file.id) {
                    files.append(file)
                }
            }
        }
        return files
    }

    private func applyCleanupResults(deletedIds: Set<UUID>, failedIds: Set<UUID>) {
        var updatedResults: [ScanResult] = []
        for result in scanResults {
            var updatedSubcategories: [ScanSubcategory] = []
            for sub in result.subcategories {
                let remainingFiles = sub.files.filter { !deletedIds.contains($0.id) }
                if !remainingFiles.isEmpty {
                    updatedSubcategories.append(ScanSubcategory(name: sub.name, files: remainingFiles))
                }
            }
            let remainingBytes = updatedSubcategories.reduce(0) { $0 + $1.totalBytes }
            if !updatedSubcategories.isEmpty {
                updatedResults.append(
                    ScanResult(item: result.item, bytes: remainingBytes, subcategories: updatedSubcategories)
                )
            }
        }

        scanResults = updatedResults
        selectedFileIds = failedIds
        scanProgress = 0
        scanStatus = "Ready to scan"
    }

    private func showCleanupAlert(totalRemoved: Int64, failedUrls: [URL]) {
        var message = "Freed space: \(formatBytes(totalRemoved))"
        if !failedUrls.isEmpty {
            let sample = failedUrls.prefix(3).map { $0.path }.joined(separator: "\n")
            message += "\nFailed to delete: \(failedUrls.count)"
            if !sample.isEmpty {
                message += "\n\n" + sample
            }
        }
        activeAlert = ActiveAlert(kind: .cleanupDone, message: message)
    }

    private func scanDots(for index: Int) -> String {
        let phase = index % 3
        if phase == 0 { return "" }
        if phase == 1 { return "." }
        return ".."
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
