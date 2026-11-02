//
//  ImportDirectory.swift
//  Feather
//

import Foundation

enum ImportDirectory {
	/// Folder the Files picker opens to when importing apps: iCloud Drive/Entertainment/Tech/ipa file
	static let url = URL(
		fileURLWithPath: "/private/var/mobile/Library/Mobile Documents/com~apple~CloudDocs/Entertainment/Tech/ipa file",
		isDirectory: true
	)
}
