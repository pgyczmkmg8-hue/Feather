//
//  GitHubAuth.swift
//  Feather
//

import Foundation
import Security

// MARK: - Token
/// Personal access token for downloading from private GitHub repositories, kept in the keychain.
enum GitHubToken {
	private static let _service = "Feather.github"
	private static let _account = "token"

	private static var _query: [String: Any] {
		[
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: _service,
			kSecAttrAccount as String: _account
		]
	}

	static var value: String? {
		var query = _query
		query[kSecReturnData as String] = true
		query[kSecMatchLimit as String] = kSecMatchLimitOne

		var result: AnyObject?
		guard
			SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
			let data = result as? Data,
			let token = String(data: data, encoding: .utf8),
			!token.isEmpty
		else {
			return nil
		}
		return token
	}

	@discardableResult
	static func save(_ token: String) -> Bool {
		delete()
		var query = _query
		query[kSecValueData as String] = Data(token.utf8)
		query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
		return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
	}

	static func delete() {
		SecItemDelete(_query as CFDictionary)
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
			var request = URLRequest(url: url)
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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

	private static func _apiRequest(_ path: String, token: String) -> URLRequest {
		var request = URLRequest(url: URL(string: "https://api.github.com/\(path)")!)
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
		return request
	}
}
