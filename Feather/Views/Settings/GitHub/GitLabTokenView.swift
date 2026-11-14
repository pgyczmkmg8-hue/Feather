//
//  GitLabTokenView.swift
//  Feather
//

import SwiftUI
import NimbleViews

// MARK: - View
struct GitLabTokenView: View {
	@State private var _token = ""
	@State private var _hasToken = GitLabToken.value != nil
	@State private var _status: String?
	@State private var _isChecking = false

	// MARK: Body
	var body: some View {
		Form {
			Section {
				SecureField(text: $_token) {
					Text(verbatim: _hasToken ? "저장됨 — 바꾸려면 새 토큰 입력" : "glpat-…")
				}
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()

				Button {
					Task { await _save() }
				} label: {
					Text(verbatim: "저장")
				}
				.disabled(_token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || _isChecking)

				if _hasToken {
					Button(role: .destructive) {
						GitLabToken.delete()
						_hasToken = false
						_status = nil
					} label: {
						Text(verbatim: "토큰 삭제")
					}
				}
			} header: {
				Text(verbatim: "개인 액세스 토큰")
			} footer: {
				Text(verbatim: "gitlab.com의 비공개 프로젝트에 있는 저장소 목록(raw 파일)과 릴리즈 파일을 받을 때만 쓰이며, 다른 사이트로는 보내지 않습니다. 토큰은 read_api 권한이면 충분합니다. 이 기기에만 저장됩니다.")
			}

			if let _status {
				Section {
					Text(verbatim: _status)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
		}
		.navigationTitle(Text(verbatim: "GitLab"))
	}

	private func _save() async {
		let token = _token.trimmingCharacters(in: .whitespacesAndNewlines)
		_isChecking = true
		defer { _isChecking = false }

		var request = URLRequest(url: URL(string: "https://gitlab.com/api/v4/user")!)
		request.setValue(token, forHTTPHeaderField: "PRIVATE-TOKEN")

		let status = try? await (URLSession.shared.data(for: request).1 as? HTTPURLResponse)?.statusCode
		guard status == 200 else {
			_status = status.map { "토큰을 확인하지 못했습니다 (HTTP \($0)). 저장하지 않았습니다." }
				?? "GitLab에 연결하지 못했습니다. 저장하지 않았습니다."
			return
		}

		_hasToken = GitLabToken.save(token)
		_status = _hasToken ? "저장했습니다." : "저장하지 못했습니다."
		if _hasToken {
			_token = ""
		}
	}
}
