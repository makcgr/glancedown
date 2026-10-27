import Foundation

/// Calls `onChange` when the file is written, including editors that save by replacing the file.
@MainActor
final class FileWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pendingNotification: DispatchWorkItem?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
        startWatching(attempt: 0)
    }

    deinit {
        source?.cancel()
    }

    private func startWatching(attempt: Int) {
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // An atomic save removes the file for a moment; try again shortly.
            if attempt < 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.startWatching(attempt: attempt + 1)
                }
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data
            if events.contains(.delete) || events.contains(.rename) {
                source.cancel()
                self.source = nil
                self.startWatching(attempt: 0)
            }
            self.scheduleNotification()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        self.source = source
        source.resume()

        if attempt > 0 {
            scheduleNotification()
        }
    }

    private func scheduleNotification() {
        pendingNotification?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        pendingNotification = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }
}
