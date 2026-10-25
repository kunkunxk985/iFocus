import Foundation

/// Compares the running app with the latest GitHub release and finds its zip.
enum AppUpdateChecker {
    static let repository = "kunkunxk985/iFocus"
    static let packageName = "iFocus.zip"

    enum Status: Equatable {
        case upToDate
        case noRelease
        case missingPackage(version: String)
        case available(version: String, package: URL)
        case failed
    }

    static func check(currentVersion: String) async -> Status {
        let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("iFocus", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code == 404 { return .noRelease }
            guard code == 200 else { return .failed }
            guard let release = try? JSONDecoder().decode(Release.self, from: data) else {
                return .failed
            }
            let remote = release.tagName
            guard isNewerRelease(remote, than: currentVersion) else { return .upToDate }
            let version = displayVersion(remote)
            guard let package = preferredPackage(among: release.assets) else {
                return .missingPackage(version: version)
            }
            return .available(version: version, package: package)
        } catch {
            return .failed
        }
    }

    /// Prefer the archive produced by packaging (`iFocus.zip`), then any other zip.
    static func preferredPackage(among assets: [ReleaseAsset]) -> URL? {
        let named = assets.first { $0.name == packageName }
            ?? assets.first { $0.name.lowercased().hasSuffix(".zip") }
        return named?.downloadURL
    }

    /// `remote` may include a leading v. Build metadata after + is ignored.
    static func isNewerRelease(_ remote: String, than local: String) -> Bool {
        let remoteParts = numericParts(remote)
        let localParts = numericParts(local)
        let count = max(remoteParts.count, localParts.count)
        for index in 0..<count {
            let r = index < remoteParts.count ? remoteParts[index] : 0
            let l = index < localParts.count ? localParts[index] : 0
            if r != l { return r > l }
        }
        return false
    }

    static func displayVersion(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("v") { text.removeFirst() }
        if let plus = text.firstIndex(of: "+") { text = String(text[..<plus]) }
        return text
    }

    private static func numericParts(_ raw: String) -> [Int] {
        displayVersion(raw)
            .split { !$0.isNumber }
            .compactMap { Int($0) }
    }

    struct ReleaseAsset: Equatable, Decodable {
        let name: String
        let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }

        init(name: String, downloadURL: URL) {
            self.name = name
            self.downloadURL = downloadURL
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            let raw = try container.decode(String.self, forKey: .browserDownloadURL)
            guard let url = URL(string: raw) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .browserDownloadURL,
                    in: container,
                    debugDescription: "Invalid download URL"
                )
            }
            downloadURL = url
        }
    }

    private struct Release: Decodable {
        let tagName: String
        let assets: [ReleaseAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case assets
        }
    }
}
