import Foundation

/// Watches filesystem paths for changes via kqueue DispatchSource and fires a debounced callback.
/// Works with both files (detects atomic rename-replace writes) and directories.
final class FileSystemWatcher: @unchecked Sendable {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWork: DispatchWorkItem?
    private let debounce: TimeInterval
    private let onChange: @Sendable () -> Void

    init(debounce: TimeInterval = 0.5, onChange: @escaping @Sendable () -> Void) {
        self.debounce = debounce
        self.onChange = onChange
    }

    func watch(paths: [String]) {
        stop()
        for path in paths {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .delete, .rename, .link],
                queue: .main
            )
            source.setEventHandler { [weak self] in self?.schedule() }
            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    private func schedule() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange() }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounce, execute: work)
    }

    deinit { stop() }
}
