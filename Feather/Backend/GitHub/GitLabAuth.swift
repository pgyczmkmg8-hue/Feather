//
//  GitLabAuth.swift
//  Feather
//

import Foundation

// MARK: - Token
/// Personal access token for reading private GitLab projects (scope `read_api`).
/// Stored like the GitHub one: in the app container, not the keychain.
enum GitLabToken {
	private static var _fileURL: URL? {
		guard let support = try? FileManager.default.url(
			for: .applicationSupportDirectory,
			in: .userDomainMask,
			appropriateFor: nil,
			create: true
		) else {
			return nil
		}
		let directory = support.appendingPathComponent("Feather", isDirectory: true)
		try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		return directory.appendingPathComponent("gitlab-token")
	}

	static var value: String? {
		guard let url = _fileURL, let data = try? Data(contentsOf: url),
			  let token = String(data: data, encoding: .utf8), !token.isEmpty else {
			return nil
		}
		return token
	}

	@discardableResult
	static func save(_ token: String) -> Bool {
		guard let url = _fileURL else { return false }
		do {
			try Data(token.utf8).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
			return true
		} catch {
			return false
		}
	}

	static func delete() {
		if let url = _fileURL {
			try? FileManager.default.removeItem(at: url)
		}
	}
}

// MARK: - Requests
enum GitLabAuth {
	private static let _host = "gitlab.com"

	/// Whether this URL is on gitlab.com and a token is saved.
	static func shouldAuthorize(_ url: URL) -> Bool {
		GitLabToken.value != nil && url.host?.lowercased() == _host
	}

	/// An authorized request for a gitlab.com URL, or nil for anything else (the token never leaves gitlab.com).
	/// Browser links are turned into API calls, since the web routes of a private project don't take the token:
	/// - gitlab.com/<project>/-/raw/<ref>/<path>               → repository/files/<path>/raw?ref=<ref>
	/// - gitlab.com/<project>/-/releases/<tag>/downloads/<file> → releases/<tag>/downloads/<file>
	static func request(for url: URL) -> URLRequest? {
		guard shouldAuthorize(url), let token = GitLabToken.value else { return nil }

		var request = URLRequest(url: _apiURL(for: url) ?? url)
		request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")
		return request
	}

	private static func _apiURL(for url: URL) -> URL? {
		let parts = url.pathComponents.filter { $0 != "/" }
		guard let marker = parts.firstIndex(of: "-"), marker >= 2, parts.count > marker + 2 else { return nil }

		let project = parts[..<marker].joined(separator: "/")
		let encodedProject = project.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? project
		let kind = parts[marker + 1]
		let rest = Array(parts[(marker + 2)...])

		switch kind {
		case "raw":
			guard rest.count >= 2 else { return nil }
			let ref = rest[0]
			let path = rest[1...].joined(separator: "/")
			let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? path
			let encodedRef = ref.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ref
			return URL(string: "https://\(_host)/api/v4/projects/\(encodedProject)/repository/files/\(encodedPath)/raw?ref=\(encodedRef)")
		case "releases":
			guard rest.count >= 3, rest[1] == "downloads" else { return nil }
			let tag = rest[0].addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? rest[0]
			let asset = rest[2...].joined(separator: "/")
			return URL(string: "https://\(_host)/api/v4/projects/\(encodedProject)/releases/\(tag)/downloads/\(asset)")
		default:
			return nil
		}
	}
}
