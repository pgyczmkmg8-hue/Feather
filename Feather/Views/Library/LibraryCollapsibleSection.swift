//
//  LibraryCollapsibleSection.swift
//  Feather
//

import SwiftUI

// MARK: - View
/// Same look as `NBSection`, but tapping the header folds the rows away.
struct LibraryCollapsibleSection<Content: View>: View {
	private var _headerText: String
	private var _count: Int
	@Binding private var _isCollapsed: Bool
	private var _isForcedExpanded: Bool
	private var _content: Content

	init(
		_ headerText: String,
		count: Int,
		isCollapsed: Binding<Bool>,
		forceExpanded: Bool = false,
		@ViewBuilder content: () -> Content
	) {
		self._headerText = headerText
		self._count = count
		self.__isCollapsed = isCollapsed
		self._isForcedExpanded = forceExpanded
		self._content = content()
	}

	private var _isShowingContent: Bool {
		_isForcedExpanded || !_isCollapsed
	}

	var body: some View {
		Section {
			if _isShowingContent {
				_content
			}
		} header: {
			Button {
				withAnimation(.snappy) {
					_isCollapsed.toggle()
				}
			} label: {
				_header
			}
			.buttonStyle(.plain)
			.disabled(_isForcedExpanded)
			.accessibilityValue(Text(_isShowingContent ? .localized("Expanded") : .localized("Collapsed")))
		}
		.headerProminence(.increased)
	}

	private var _header: some View {
		HStack(alignment: .center, spacing: 6) {
			Text(_headerText)
				.fontWeight(.bold)
				.font(.title2)
				.foregroundStyle(.primary)

			Image(systemName: "chevron.down")
				.font(.system(size: 13, weight: .semibold))
				.foregroundStyle(.secondary)
				.rotationEffect(.degrees(_isShowingContent ? 0 : -90))

			Spacer()

			_countBadge
		}
		.contentShape(Rectangle())
		.textCase(nil)
		.offset(y: 2)
	}

	@ViewBuilder
	private var _countBadge: some View {
		let badge = Text(_count.description)
			.font(.caption)
			.foregroundStyle(.secondary)
			.contentTransition(.numericText())
			.padding(.horizontal, 8)
			.padding(.vertical, 4.4)
			.background(Color(uiColor: .quaternarySystemFill))
			.clipShape(Capsule())

		if #available(iOS 26.0, *) {
			badge.glassEffect()
		} else {
			badge
		}
	}
}
