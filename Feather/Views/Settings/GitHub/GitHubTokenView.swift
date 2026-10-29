//
//  GitHubTokenView.swift
//  Feather
//

import SwiftUI
import NimbleViews

// MARK: - View
struct GitHubTokenView: View {
	@State private var _token = ""
	@State private var _hasToken = GitHubToken.value != nil
	@State private var _status: String?
	@State private var _isChecking = false

	// MARK: Body
	var body: some View {
		Form {
			Section {
				SecureField(text: $_token) {
					Text(verbatim: _hasToken ? "저장됨 — 바꾸려면 새 토큰 입력" : "github_pat_… 또는 ghp_…")
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
						GitHubToken.delete()
						_hasToken = false
						_status = nil
					} label: {
						Text(verbatim: "토큰 삭제")
					}
				}
			} header: {
				Text(verbatim: "개인 액세스 토큰")
			} footer: {
				Text(verbatim: "비공개 저장소의 릴리즈(github.com/…/releases/download/…)와 raw 파일을 받을 때만 쓰입니다. Fine-grained 토큰이라면 해당 저장소의 Contents 읽기 권한만 주면 됩니다. 토큰은 이 기기의 키체인에 저장됩니다.")
			}

			if let _status {
				Section {
					Text(verbatim: _status)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}
		}
		.navigationTitle(Text(verbatim: "GitHub"))
	}

	private func _save() async {
		let token = _token.trimmingCharacters(in: .whitespacesAndNewlines)
		_isChecking = true
		defer { _isChecking = false }

		var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

		let status = try? await (URLSession.shared.data(for: request).1 as? HTTPURLResponse)?.statusCode
		guard status == 200 else {
			_status = status.map { "토큰을 확인하지 못했습니다 (HTTP \($0)). 저장하지 않았습니다." }
				?? "GitHub에 연결하지 못했습니다. 저장하지 않았습니다."
			return
		}

		_hasToken = GitHubToken.save(token)
		_status = _hasToken ? "저장했습니다." : "키체인에 저장하지 못했습니다."
		if _hasToken {
			_token = ""
		}
	}
}
