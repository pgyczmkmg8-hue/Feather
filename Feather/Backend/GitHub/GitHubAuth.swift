//
//  GitHubAuth.swift
//  Feather
//

import Foundation
import Security

// MARK: - Token
/// Personal access token for downloading from private GitHub repositories.
/// Kept in the app container rather than the keychain, since keychain items stop being readable after an update signed by another certificate.
enum GitHubToken {
	private static let _legacyService = "Feather.github"
	private static let _legacyAccount = "token"

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
		return directory.appendingPathComponent("github-token")
	}

	static var value: String? {
		if let url = _fileURL, let data = try? Data(contentsOf: url),
		   let token = String(data: data, encoding: .utf8), !token.isEmpty {
			return token
		}
		return _migrateLegacyKeychainToken()
	}

	@discardableResult
	static func save(_ token: String) -> Bool {
		guard let url = _fileURL else { return false }
		do {
			try Data(token.utf8).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
			_deleteLegacyKeychainToken()
			return true
		} catch {
			return false
		}
	}

	static func delete() {
		if let url = _fileURL {
			try? FileManager.default.removeItem(at: url)
		}
		_deleteLegacyKeychainToken()
	}

	/// Tokens saved by earlier builds stay in the keychain, so move them over once.
	private static func _migrateLegacyKeychainToken() -> String? {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: _legacyService,
			kSecAttrAccount as String: _legacyAccount,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		var result: AnyObject?
		guard
			SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			let data = result as? Data,
			let token = String(data: data, encoding: .utf8),
			!token.isEmpty
		else {
			return nil
		}
		save(token)
		return token
	}

	private static func _deleteLegacyKeychainToken() {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: _legacyService,
			kSecAttrAccount as String: _legacyAccount
		]
		SecItemDelete(query as CFDictionary)
	}
}

// MARK: - Requests
enum GitHubAuth {
	enum Error: LocalizedError {
		case assetNotFound(String)
		case http(Int)

		var errorDescription: String? {
			switch self {
			case .assetNotFound(let name):
				return "GitHub 릴리즈에서 \(name) 파일을 찾지 못했습니다."
			case .http(let status):
				return "GitHub API HTTP \(status) — 토큰 권한이나 주소를 확인하세요."
			}
		}
	}

	/// github.com/<owner>/<repo>/releases/download/<tag>/<file>
	/// github.com/<owner>/<repo>/releases/latest/download/<file>
	private struct _ReleaseAsset {
		let owner: String
		let repo: String
		let tag: String? // nil means latest
		let fileName: String

		init?(_ url: URL) {
			guard url.host?.lowercased() == "github.com" else { return nil }
			let parts = url.pathComponents.filter { $0 != "/" }
			guard parts.count >= 5, parts[2] == "releases" else { return nil }

			if parts.count == 6, parts[3] == "download" {
				tag = parts[4]
			} else if parts.count == 6, parts[3] == "latest", parts[4] == "download" {
				tag = nil
			} else {
				return nil
			}
			owner = parts[0]
			repo = parts[1]
			fileName = parts[5]
		}
	}

	/// Whether a download from this URL should go through the token, which is only when one is saved.
	static func shouldAuthorize(_ url: URL) -> Bool {
		guard GitHubToken.value != nil else { return false }
		return _ReleaseAsset(url) != nil || url.host?.lowercased() == "raw.githubusercontent.com"
	}

	/// Turns a browser release link into an authorized API request, since private release links 404 even with a token.
	static func request(for url: URL) async throws -> URLRequest {
		guard let token = GitHubToken.value else { return URLRequest(url: url) }

		guard let asset = _ReleaseAsset(url) else {
			// raw.githubusercontent.com is cached for minutes, so read files through the contents API to see a new release right away
			if let contents = _contentsRequest(for: url, token: token) {
				return contents
			}
			var request = URLRequest(url: url)
			// the token belongs to GitHub only; GitLab (or anything else) must never see it
			if let host = url.host?.lowercased(), host == "github.com" || host.hasSuffix(".github.com") || host.hasSuffix(".githubusercontent.com") {
				request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
			}
			return request
		}

		let release = asset.tag.map { "tags/\($0)" } ?? "latest"
		var lookup = _apiRequest("repos/\(asset.owner)/\(asset.repo)/releases/\(release)", token: token)
		lookup.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

		let (data, response) = try await URLSession.shared.data(for: lookup)
		if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
			throw Error.http(status)
		}

		struct Release: Decodable {
			struct Asset: Decodable {
				let id: Int
				let name: String
			}
			let assets: [Asset]
		}
		let decodedName = asset.fileName.removingPercentEncoding ?? asset.fileName
		guard let id = try JSONDecoder().decode(Release.self, from: data).assets.first(where: { $0.name == decodedName })?.id else {
			throw Error.assetNotFound(decodedName)
		}

		var download = _apiRequest("repos/\(asset.owner)/\(asset.repo)/releases/assets/\(id)", token: token)
		download.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
		return download
	}

	/// Fetches and decodes JSON (a source, say) from a private repository.
	static func decode<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
		var request = try await request(for: url)
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

		let (data, response) = try await URLSession.shared.data(for: request)
		if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
			throw Error.http(status)
		}
		return try JSONDecoder().decode(type, from: data)
	}

	/// raw.githubusercontent.com/<owner>/<repo>/<ref>/<path> as a contents API request returning the raw file.
	private static func _contentsRequest(for url: URL, token: String) -> URLRequest? {
		guard url.host?.lowercased() == "raw.githubusercontent.com" else { return nil }

		var parts = url.pathComponents.filter { $0 != "/" }
		guard parts.count >= 4 else { return nil }
		let owner = parts.removeFirst()
		let repo = parts.removeFirst()
		if parts.count >= 3, parts[0] == "refs", parts[1] == "heads" {
			parts.removeFirst(2)
		}
		let ref = parts.removeFirst()
		let path = parts.joined(separator: "/")

		var request = _apiRequest("repos/\(owner)/\(repo)/contents/\(path)?ref=\(ref)", token: token)
		request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
		return request
	}

	private static func _apiRequest(_ path: String, token: String) -> URLRequest {
		var request = URLRequest(url: URL(string: "https://api.github.com/\(path)")!)
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
		return request
	}
}
