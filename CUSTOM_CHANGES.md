# 개조 내역 (pgyczmkmg8-hue/Feather)

원본 [seomin0610/Feather](https://github.com/seomin0610/Feather)의 비공개 개조판이다.
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
| Feather 자체 업데이트를 우리 피드에서 확인 | `UpdateManager.swift`의 `FeatherUpdate.repositoryURL`(= `pgyczmkmg8-hue/Feather/main/custom-repo.json`)과 `_fetchRepository`의 `GitHubAuth` 분기, `custom-repo.json` |
| MACHU 대체 아이콘 | `Feather/Resources/Icons/MACHU/`, `Info.plist`의 `CFBundleIcons`·`CFBundleIcons~ipad` 안 `MACHU` 항목, `AppIconView.swift`의 `"MACHU"` 섹션 |
| iPhone 가로 방향 허용 (폴더블 기기에서 전체화면) | `Feather.xcodeproj/project.pbxproj`의 `INFOPLIST_KEY_UISupportedInterfaceOrientations` (Portrait + LandscapeLeft + LandscapeRight, Debug·Release 둘 다) |
| 파일 가져오기 탐색기 기본 경로 고정 (iCloud Drive/Entertainment/Tech/ipa file) | `Feather/Utilities/ImportDirectory.swift`, `NimbleKit/.../FileImporterRepresentableView.swift`의 `initialDirectory`, `LibraryView.swift`의 `initialDirectory: ImportDirectory.url` |
| 탭바(iPad·폴더블)의 저장소 아이콘이 검은 원으로 나오는 문제 수정 | `Feather/Views/TabView/Bars/ExtendedTabbarView.swift`의 `_icon` (`withRenderingMode(.alwaysOriginal)`) |
| 원본 자동 동기화 | `.github/workflows/sync_upstream.yml`, `tools/sync-upstream.sh` |
| 우리 릴리즈 | `tools/release-custom.sh` (태그 `custom-<버전>`, `v*` 태그는 쓰지 않는다) |
| 원본 `update_repo` 워크플로가 우리 릴리즈에 돌지 않게 | `.github/workflows/update_repo.yml`의 job `if: startsWith(…, 'v')` |

## 원본의 `app-repo.json`

원본 것을 그대로 받는다. 우리 업데이트 정보는 `custom-repo.json`에만 쓴다.

## 원본 업데이트 반영 기록

<!-- 날짜 · 합친 원본 커밋 · 충돌 처리 · 릴리즈 -->
