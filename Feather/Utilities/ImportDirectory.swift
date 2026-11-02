//
//  ImportDirectory.swift
//  Feather
//

import Foundation

/// Folder the Files picker opens to when importing apps, chosen in settings and kept as a security-scoped bookmark.
enum ImportDirectory {
	static let bookmarkKey = "Feather.importDirectoryBookmark"

	/// The saved folder, or nil when none is chosen or it can no longer be resolved.
	static var url: URL? {
		guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }

		var isStale = false
		guard let url = try? URL(
			resolvingBookmarkData: data,
			options: [],
			relativeTo: nil,
			bookmarkDataIsStale: &isStale
		) else {
			return nil
		}

		// the picker needs access to the folder while it is open, so keep it for the session
		_ = url.startAccessingSecurityScopedResource()
		if isStale {
			save(url)
		}
		return url
	}

	/// Remembers a folder picked in the settings.
	@discardableResult
	static func save(_ url: URL) -> Bool {
		let didAccess = url.startAccessingSecurityScopedResource()
		defer {
			if didAccess { url.stopAccessingSecurityScopedResource() }
		}
		guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
			return false
		}
		UserDefaults.standard.set(data, forKey: bookmarkKey)
		return true
	}

	static func reset() {
		UserDefaults.standard.removeObject(forKey: bookmarkKey)
	}
}
