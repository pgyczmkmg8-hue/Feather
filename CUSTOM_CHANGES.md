# 개조 내역 (Yami_Q_Ray/Feather, GitLab·GitHub 양쪽 운영)

원본 [seomin0610/Feather](https://github.com/seomin0610/Feather)의 개조판이다. GitHub 계정이 한 번 정지된 뒤 **GitLab(`gitlab.com/Yami_Q_Ray/Feather`, 공개)을 정본으로, GitHub(`github.com/pgyczmkmg8-hue/Feather`, 공개 포크)를 미러로 함께 운영한다.** 로컬 `origin`이 GitLab, `github`가 GitHub 미러다(`private`은 옛 비공개 저장소). 릴리즈·피드·다운로드는 GitLab이 먼저이고, 앱은 GitLab 피드를 읽지 못하면 GitHub 피드(`custom-repo-github.json`)로 넘어간다. 푸시는 `origin`과 `github` 둘 다에 한다(릴리즈 스크립트는 GitHub 쪽을 자동으로 맞춘다).
원본을 합칠 때 아래 개조는 반드시 유지한다.

## 유지할 것

- **번들 ID `thewonderofyou.Feather`는 바꾸지 않는다.** (`Feather.xcconfig`의 `FEATHER_PRODUCT_BUNDLE_IDENTIFIER`)
- **버전**: `FEATHER_PROJECT_VERSION`은 원본 값을 그대로 받는다. 우리 빌드 번호(`2.9.4.1` 등)는 `tools/release-custom.sh`가 빌드할 때만 붙인다.

## 개조 목록

| 기능 | 파일 |
|---|---|
| 라이브러리 "서명됨"/"가져옴" 접기 (상태 저장, 검색 중 자동 펼침) | `Feather/Views/Library/LibraryCollapsibleSection.swift`(신규), `Feather/Views/Library/LibraryView.swift`의 `LibraryCollapsibleSection` 호출과 `@AppStorage("Feather.library.is…Collapsed")` 두 줄 |
| `feather://install/<url>` 확인창 없이 다운로드 → 자동 서명·설치 | `Feather/FeatherApp.swift`의 `/install/` 처리 (`AppUpdate.downloadIDPrefix + "URLScheme_"` ID로 업데이트 흐름 재사용) |
| 비공개 GitHub 릴리즈/raw 다운로드 (토큰) | `Feather/Backend/GitHub/GitHubAuth.swift`(신규), `Feather/Views/Settings/GitHub/GitHubTokenView.swift`(신규), `SettingsView.swift`의 "GitHub 토큰" 항목, `DownloadManager.swift`의 `GitHubAuth.shouldAuthorize` 분기·`resumeDownload`의 `originalRequest` 사용·파일 끝 `// MARK: - GitHub` 확장 |
| 비공개 GitLab 프로젝트의 저장소 목록(raw)·릴리즈 파일 받기 (토큰) | `Feather/Backend/GitHub/GitLabAuth.swift`(신규), `Feather/Views/Settings/GitHub/GitLabTokenView.swift`(신규), `SettingsView.swift`의 "GitLab 토큰" 항목, `GitHubAuth.swift`의 `GitLabAuth` 분기(`shouldAuthorize`·`request(for:)`) |
| Feather 자체 업데이트를 우리 피드에서 확인 (GitLab 먼저, 못 읽으면 GitHub 미러 피드) | `UpdateManager.swift`의 `FeatherUpdate.repositoryURL`(= GitLab API `…/repository/files/custom-repo.json/raw?ref=main`, 토큰 없이 읽음)·`mirrorRepositoryURL`(= GitHub raw `custom-repo-github.json`)·`checkFeatherUpdateNow`의 폴백(`GitHubAuth.decodePublic`으로 토큰 없이 읽음)과 `_fetchRepository`의 `GitHubAuth` 분기, `custom-repo.json`(다운로드 주소는 GitLab 릴리즈 `…/-/releases/<태그>/downloads/Feather.ipa`)·`custom-repo-github.json`(같은 피드, 다운로드 주소는 GitHub 릴리즈 `…/releases/download/<태그>/Feather.ipa`. 릴리즈 스크립트가 만든다) |
| MACHU 대체 아이콘 | `Feather/Resources/Icons/MACHU/`, `Info.plist`의 `CFBundleIcons`·`CFBundleIcons~ipad` 안 `MACHU` 항목, `AppIconView.swift`의 `"MACHU"` 섹션 |
| iPhone 가로 방향 허용 (폴더블 기기에서 전체화면) | `Feather.xcodeproj/project.pbxproj`의 `INFOPLIST_KEY_UISupportedInterfaceOrientations` (Portrait + LandscapeLeft + LandscapeRight, Debug·Release 둘 다) |
| 파일 가져오기 탐색기 기본 경로: 설정에서 고른 폴더(북마크), 없으면 iCloud Drive/Entertainment/Tech/ipa file | `Feather/Utilities/ImportDirectory.swift`, `SettingsView.swift`의 "가져오기 기본 경로" 항목·시트, `NimbleKit/.../FileImporterRepresentableView.swift`의 `initialDirectory`, `LibraryView.swift`의 `initialDirectory: ImportDirectory.url` |
| 탭바(iPad·폴더블)에서 `TabSection("Sources")` 전체 제거 — 저장소별 탭과 "모든 저장소" 탭 (저장소 탭에서 볼 수 있음) | `Feather/Views/TabView/Bars/ExtendedTabbarView.swift` (섹션, `_sources`, `viewModel`, 저장소 추가 시트, `_icon` 삭제) |
| 라이브러리의 회전(업데이트 확인) 버튼이 Feather 업데이트 확인 실패 이유를 알림으로 표시 | `LibraryView.swift` 회전 버튼의 `featherCheckError`·`featherCheckNote` 알림, `GitHubAuth.swift`의 `_contentsRequest`(raw 주소를 캐시 없는 contents API로 읽음), `UpdateManager.swift`의 `FeatherUpdateCheck`·`checkFeatherUpdateNow`·`featherCheckError`·`_featherUpdate(in:)` |
| 앱이 포그라운드로 돌아올 때 업데이트 자동 확인 (5분 간격 제한) | `TabbarView.swift`·`ExtendedTabbarView.swift`의 `didBecomeActiveNotification` `.onReceive` |
| 설정 화면의 "GitLab 저장소"·"GitHub 저장소" 링크 | `SettingsView.swift`의 `_gitlabUrl`·`_githubUrl`과 `_feedback()`의 버튼 |
| 원본 자동 동기화 | GitHub: `.github/workflows/sync_upstream.yml`이 매일 GitHub `main`에 머지한다(GitLab에서는 돌지 않는다). 로컬: `tools/sync-upstream.sh`(GitLab과 GitHub에 push). GitHub가 먼저 머지했다면 `git fetch github && git merge github/main` 한 뒤 양쪽에 push한다 |
| 우리 릴리즈 | `tools/release-custom.sh` (GitLab에 `glab release create`로 올리고 `custom-repo.json`·`custom-repo-github.json`을 갱신. 이어서 `tools/mirror-github.sh`가 GitHub에 `main`·태그·릴리즈(IPA)를 미러링하며, 실패해도 경고만 한다. 태그 `custom-<버전>`, `v*` 태그는 쓰지 않는다) |
| 원본 `update_repo` 워크플로가 우리 릴리즈에 돌지 않게 | `.github/workflows/update_repo.yml`의 job `if: startsWith(…, 'v')` |

## 비공개 저장소와 GitHub 토큰

이 저장소는 공개지만, **설정 → GitHub 토큰 기능은 유지한다.** 비공개 GitHub 저장소의 릴리즈·raw 파일을 받는 데 쓰기 때문이다.

- 토큰은 앱 안에서 사용자가 직접 입력하며, 기기에만 저장된다. 저장소나 채팅에 적지 않는다.
- 이 저장소는 GitLab·GitHub 둘 다 공개라 **업데이트 확인에 토큰이 필요 없다.** 토큰은 GitHub 주소에만 붙고, 다른 호스트(GitLab 등)로는 절대 보내지 않는다(`GitHubAuth.request`). GitHub 미러 피드는 저장된 토큰이 만료됐어도 읽히도록 일부러 토큰 없이 읽는다(`GitHubAuth.decodePublic`).
- 이 포크를 쓰는 다른 사람도 **자기만의 비공개 저장소**로 앱 소스나 업데이트 피드를 운영할 수 있다. 그럴 때는 자기 토큰(`repo` 읽기 권한)을 설정에 넣으면 된다.
- 비공개 저장소를 쓰려면 `FeatherUpdate.repositoryURL`·`mirrorRepositoryURL`(`UpdateManager.swift`)과 `tools/release-custom.sh`의 `REPO`·`GITHUB_REPO`·`URL`, `tools/mirror-github.sh`의 `GITLAB_REPO`·`GITHUB_REPO`, `custom-repo.json`·`custom-repo-github.json`의 주소를 자기 저장소로 바꾼다. 한 곳만 쓸 거면 `mirrorRepositoryURL`을 `repositoryURLs`에서 빼고 릴리즈 스크립트의 미러 단계를 지운다.

## 원본의 `app-repo.json`

원본 것을 그대로 받는다. 우리 업데이트 정보는 `custom-repo.json`에만 쓴다.

## 원본 업데이트 반영 기록

<!-- 날짜 · 합친 원본 커밋 · 충돌 처리 · 릴리즈 -->
