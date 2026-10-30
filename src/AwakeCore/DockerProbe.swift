import Foundation

/// Asks Docker Desktop, over its own socket, whether any container is running.
enum DockerProbe {
    static let desktopSocket = NSHomeDirectory() + "/.docker/run/docker.sock"

    /// False whenever Docker can't be asked or doesn't answer clearly, so a busy Docker is never paused.
    static func isIdle(socketPath: String = desktopSocket) -> Bool {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        // Runs on the main thread while the lid is closed, so give up quickly.
        var timeout = timeval(tv_sec: 2, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        // A write to a socket Docker already closed would otherwise raise SIGPIPE and kill the app.
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(socketPath.utf8CString)
        guard path.count <= MemoryLayout.size(ofValue: address.sun_path) else { return false }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            path.withUnsafeBytes { buffer.copyMemory(from: $0) }
        }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard connected == 0 else { return false }

        // HTTP/1.0 makes Docker close the connection after a plain, unchunked answer.
        let request = Array("GET /containers/json HTTP/1.0\r\nHost: docker\r\n\r\n".utf8)
        guard write(fd, request, request.count) == request.count else { return false }
        var response = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while response.count < 1 << 20 {
            let count = read(fd, &buffer, buffer.count)
            guard count > 0 else { break }
            response.append(contentsOf: buffer.prefix(count))
        }
        return isIdle(response: String(decoding: response, as: UTF8.self))
    }

    static func isIdle(response: String) -> Bool {
        let parts = response.components(separatedBy: "\r\n\r\n")
        guard parts.count >= 2, let status = parts[0].split(separator: " ").dropFirst().first, status == "200",
              let containers = try? JSONSerialization.jsonObject(with: Data(parts[1].utf8)) as? [Any]
        else { return false }
        return containers.isEmpty
    }
}
