//
//  ImportDirectory.swift
//  Feather
//

import Foundation

/// Folder the Files picker opens to when importing apps.
/// A folder chosen in settings wins, since it is picked on this device and always resolves; the fixed iCloud Drive folder is the fallback.
enum ImportDirectory {
	private static let _bookmarkKey = "Feather.importDirectoryBookmark"

	/// iCloud Drive/Entertainment/Tech/ipa file
	private static let _fallback = URL(
		fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Entertainment/Tech/ipa file",
		isDirectory: true
	)

	/// The folder chosen in settings, nil when none is saved or it can no longer be resolved.
	static var chosen: URL? {
		guard let data = UserDefaults.standard.data(forKey: _bookmarkKey) else { return nil }

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

	static var url: URL {
		chosen ?? _fallback
	}

	@discardableResult
	static func save(_ url: URL) -> Bool {
		let didAccess = url.startAccessingSecurityScopedResource()
		defer {
			if didAccess { url.stopAccessingSecurityScopedResource() }
		}
		guard let data = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) else {
			return false
		}
		UserDefaults.standard.set(data, forKey: _bookmarkKey)
		return true
	}

	static func reset() {
		UserDefaults.standard.removeObject(forKey: _bookmarkKey)
	}
}
