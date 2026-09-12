# 星笺 · Starfolio · 스타폴리오

A quiet, native macOS wallpaper app for astronomy. Real observations, a little knowledge, and a clear path back to the source.

![星笺中文界面](docs/screenshots/chinese.jpg)

## 内容更新 / Content update / 콘텐츠 업데이트

**中文：** 独立的 macOS 星空壁纸应用。中文、英文、韩文覆盖应用内界面、壁纸短文和知识详情；支持跟随系统或手动切换。内置宇宙悬崖、土星与它的环、帕拉纳尔银河三张精选图片，可离线浏览、搜索、切换纯图与轻知识、设置壁纸、导出 PNG、按小时或每日轮换，以及登录时启动。浏览图片不会立即换桌面。

**English:** An independent macOS astronomy wallpaper app with Chinese, English and Korean interfaces, captions and reading notes. Three curated images work offline: Cosmic Cliffs, Saturn & Its Rings, and Milky Way over Paranal. Browse and search, switch between image-only and short-caption wallpapers, apply to connected displays, export PNG, rotate hourly or daily, and launch at login. Browsing alone does not change the desktop.

**한국어:** 중국어·영어·한국어 인터페이스와 설명을 제공하는 독립형 macOS 천문 배경화면 앱입니다. 우주의 절벽, 토성과 고리, 파라날의 은하수 등 세 가지 엄선된 이미지를 오프라인으로 감상할 수 있습니다. 검색, 이미지 전용 모드와 짧은 설명 모드, 배경화면 설정, PNG 내보내기, 시간별·일별 자동 변경, 로그인 시 실행을 지원합니다. 이미지를 둘러보는 것만으로는 배경화면이 바뀌지 않습니다.

## 0.3.0 日常使用完善 / Library controls / 도감 관리

**中文：** 新增收藏、只看收藏、隐藏和恢复隐藏图片；设置中可选择「仅轮播收藏」。没有可用收藏时暂停换图，不会改用其他图片。浏览位置与轮播独立。可选择推荐构图、完整显示或铺满屏幕，预览、导出和桌面设置一致。

「下载内容占用」中可清理可重建的批次预览，或修复图库索引。修复会保留旧索引备份及所有原文件，排除无法读取的批次；原图损坏时不能凭索引修复重建原图。清理不会删除桌面壁纸或原图。修复后可再次尝试内容更新。若恢复时无法确认批次顺序，不显示「查看新增」，下一次成功更新后恢复显示。

已下载卡片也会应用已确认的术语纠错，例如 Trifid Nebula 的中文误译修正为「三裂星云」；原始下载文案仍保留。新卡按来源类别归类。此规则不是对全部翻译的人工审校，也不会自动重译全部旧卡。

**English:** Favorite, filter and hide images; restore hidden images in Settings. Favorites-only rotation pauses when no eligible favorites remain. Browsing does not move the rotation cursor. Choose recommended framing, fit or fill for preview, export and desktop. Downloaded storage offers preview-cache cleanup and index repair, preserving original images and desktop renders. Repair excludes unreadable batches and backs up the old index; it cannot reconstruct damaged photographs. Known terminology corrections also apply to existing cards without rewriting downloaded originals.

**한국어:** 즐겨찾기, 즐겨찾기 필터, 이미지 숨기기와 설정에서 복원을 지원합니다. 즐겨찾기만 자동 변경할 때 해당 이미지가 없으면 변경을 일시 중지합니다. 탐색 위치와 자동 변경 순서는 독립적입니다. 권장·전체 표시·화면 채우기를 선택할 수 있습니다. 다운로드 저장 공간에서 미리보기 캐시 삭제와 색인 복구가 가능합니다. 원본과 바탕화면 파일은 유지되며, 복구 전에 이전 색인을 보관합니다. 손상된 원본 사진을 복원하는 기능은 아닙니다. 기존 카드에도 확인된 용어 교정이 적용되지만 전체 번역을 교정한 것은 아닙니다.

## 点击「内容更新」会发生什么

应用会从 ESA/Webb 与 ESA/Hubble 官方近期图片中筛选真实天文观测，下载图片和说明，选取完整原文段落，使用 Apple 本机翻译制作中英韩内容，再生成壁纸并加入本机图库。每次最多新增 3 张；重复图片会跳过。使用「查看新增」挑选，再设置壁纸或开启每小时／每日轮播。更新不会改变当前选图或立即替换桌面。

首次制作可能需要同意 macOS 下载翻译语言。新增中文和韩文会标明机器翻译，英文保留官方原文，并附来源、完整图片署名和使用条款。下载完成后可离线使用；这不是无人审核的生成式天文知识。少量已发现的天文术语误译会按原文校正，仍可能存在其他翻译错误。

**English:** Click **Content update** to discover recent ESA/Webb and ESA/Hubble observations, download images and source excerpts, translate them on device into Chinese and Korean, render wallpapers, and add up to three cards to your local library. **View new** filters the additions; you choose what to apply or include in rotation. macOS may ask to download translation languages. New translations are labeled as machine translated and retain source links and credits.

**한국어:** **콘텐츠 업데이트**를 누르면 ESA/Webb와 ESA/Hubble의 최근 관측 이미지를 찾아 다운로드하고, 공식 설명을 기기에서 번역해 한 번에 최대 세 개의 콘텐츠를 보관함에 추가합니다. **새 콘텐츠 보기**에서 고른 뒤 배경화면으로 설정하거나 자동 변경을 켤 수 있습니다. 업데이트만으로 현재 배경화면이 바뀌지는 않습니다. 처음에는 macOS가 번역 언어 다운로드 동의를 요청할 수 있습니다. 기계 번역 표시와 원문 출처·이미지 크레딧이 함께 제공됩니다.

## 应用版本更新 / App updates / 앱 업데이트

从 **0.3.1** 起，应用在正常启动时自动检查 GitHub 发布版本，也可在「设置 → 检查应用更新」手动检查。发现带 Apple Silicon 安装包的新版本后，点击「查看并下载新版」打开官方发布页，再退出并手动替换应用；图库和收藏保留。检查包含开发预览版，不会静默下载安装。GitHub 只推送代码不会提示更新，必须发布带有 `Starfolio-版本号-macOS-arm64.zip` 的 Release。

**0.3.0 及更旧版本没有这个入口，需要先手动安装一次 0.3.1。** 图片和知识仍使用独立的「内容更新」。

**English:** Starting with 0.3.1, normal launches check GitHub releases, including previews. Settings also offers **Check app updates**. A newer release with the Apple Silicon ZIP enables a link to the official release page. Download, quit, and replace the app manually; your library and favorites remain. Older versions need one manual upgrade to 0.3.1. Source-code pushes alone do not trigger updates.

**한국어:** 0.3.1부터 앱 실행 시 GitHub의 새 버전을 확인하며, 설정에서도 확인할 수 있습니다. 미리보기 버전도 포함됩니다. Apple Silicon 설치 파일이 있는 새 버전은 공식 다운로드 페이지로 연결됩니다. 다운로드 후 앱을 종료하고 직접 교체하세요. 도감과 즐겨찾기는 유지됩니다. 이전 버전은 먼저 0.3.1을 수동 설치해야 합니다. 코드만 업로드하면 업데이트 알림이 표시되지 않습니다.

## 安装与首次打开 / Install and open / 설치 및 실행

### 中文

当前下载包适用于 **Apple Silicon（M 系列芯片）Mac**，要求 macOS 15 或更新版本；macOS 15 的实际运行仍待验证。使用下载包无需安装 Xcode 或开发工具。此开发预览尚未经过 Apple 公证，首次打开可能被 macOS 拦截。

1. 打开本仓库的 [Releases 下载页](https://github.com/ykopp/starfolio-wallpaper/releases)，选择版本下的 **Assets**，下载 `Starfolio-版本号-macOS-arm64.zip`，不要选择 `Source code`。
2. 双击 ZIP 解压，将 `Starfolio.app` 拖入 Finder 的「应用程序」文件夹。如果更新旧版，先从星笺菜单退出应用，再替换旧的 `.app`；已下载图库保存在应用之外。
3. 在「应用程序」中双击星笺。如果提示「无法验证开发者」或「Apple 无法检查是否包含恶意软件」，先关闭提示。确认文件来自本仓库的发布页后，打开 **苹果菜单 → 系统设置 → 隐私与安全性**，向下找到星笺被阻止的记录，点击 **「仍要打开」**，按提示输入登录密码或使用 Touch ID，再确认「打开」。这是针对这个应用的单独放行；不需要关闭 Mac 的整体安全保护。操作依据：[Apple 官方打开指引](https://support.apple.com/zh-cn/102445)。
4. 成功打开后，可以先浏览内置图片，选好后点击「设为壁纸」。「内容更新」需要联网，首次制作可能由 macOS 提示下载翻译语言；允许后即可制作中英韩新内容。

**遇到其他提示：** 如果没有「仍要打开」，重新双击一次应用后再查看设置；该入口通常在尝试打开后的一小时内可用，受单位管理的 Mac 也可能限制此操作。若提示「已损坏」、明确检测到恶意软件，或放行后仍无法启动，请不要把它当成普通未公证提示强行绕过：先从发布页重新下载；仍有问题时，在 [Issues](https://github.com/ykopp/starfolio-wallpaper/issues) 附上完整报错、macOS 版本、芯片型号和应用版本。[Apple 关于未知开发者应用的说明](https://support.apple.com/zh-cn/guide/mac-help/mh40616/mac)

### English

The download is for Apple Silicon Macs running macOS 15 or later; macOS 15 runtime compatibility is not yet verified. Download the `macOS-arm64.zip` from [Releases](https://github.com/ykopp/starfolio-wallpaper/releases), unzip it, and drag `Starfolio.app` into Applications. Quit the previous version before replacing it. No developer tools are required.

This preview is not Apple-notarized. If macOS blocks it because the developer cannot be verified, first attempt to open it, then—after confirming you downloaded it from this repository—go to **System Settings → Privacy & Security → Open Anyway** and confirm. Do not disable system-wide protection. For damaged-app or detected-malware alerts, re-download and report persistent errors rather than bypassing them. See [Apple’s instructions](https://support.apple.com/en-us/102445). Content updates may first request permission to download translation languages.

### 한국어

다운로드 파일은 macOS 15 이상을 사용하는 Apple Silicon Mac용이며, macOS 15에서의 실제 실행은 아직 검증하지 않았습니다. [Releases](https://github.com/ykopp/starfolio-wallpaper/releases)에서 `macOS-arm64.zip`을 받아 압축을 풀고, `Starfolio.app`을 응용 프로그램 폴더로 옮기세요. 기존 버전은 종료한 뒤 교체하세요. 개발 도구는 필요하지 않습니다.

이 미리 보기 버전은 Apple 공증을 받지 않았습니다. 개발자를 확인할 수 없다는 이유로 차단되면, 이 저장소에서 받은 파일인지 확인한 뒤 **시스템 설정 → 개인정보 보호 및 보안 → 그래도 열기**에서 실행을 허용하세요. 시스템 전체의 보안 기능을 끌 필요는 없습니다. 손상 또는 악성 소프트웨어 감지 경고는 일반적인 개발자 확인 경고와 구분하고, 다시 다운로드한 뒤에도 문제가 있으면 Issues에 알려 주세요. [Apple 공식 안내](https://support.apple.com/ko-kr/102445)를 참고하세요. 콘텐츠 업데이트 시 번역 언어 다운로드 동의가 필요할 수 있습니다.

## Build from source

macOS 15 or later, Swift 6.1 or later, Xcode or compatible Command Line Tools. No account, API key or network connection is needed to use the bundled images. Opening source links uses your browser.

```sh
./script/build_and_run.sh             # build and launch dist/Starfolio.app
./script/build_and_run.sh --preview   # isolated UI; never changes the desktop
./script/build_and_run.sh --verify    # packaged resources, translations, image hashes
./script/build_and_run.sh --build     # build the .app without launching it
./script/test.sh
```

The build script signs locally with an ad-hoc signature. This development build is **not Apple-notarized**. A build made from this checkout targets the machine's current architecture; the initial downloadable build is for Apple Silicon. macOS 15 compatibility is declared but has not been exercised on a macOS 15 machine.

The current macOS 27 Command Line Tools SDK lacks its SwiftUI macro plug-in. When the stable macOS 26.5 SDK is also installed, the scripts select it for this build only. They do not change the computer's selected developer tools.

## Using the app

- Choose an image, read its story, then use **Set wallpaper**. Each connected display gets a render sized to its pixel dimensions; the app shows per-display results.
- **Image only** removes the knowledge caption and keeps the image credit. **Export wallpaper** saves a 2560 × 1440 PNG.
- Language and caption-mode changes update a previously applied Starfolio wallpaper. Browsing another image does not apply that selection.
- Rotation defaults to off. Hourly/daily rotation requires the app to remain running. Closing the main window leaves the menu-bar app running; Quit stops it.
- Sleep, display reconnection and Space changes trigger a reapply of the last requested Starfolio image. Arbitrary inactive Spaces and macOS wallpaper changes outside the app are not fully controllable.
- App content uses the selected language. macOS-owned menus, permission prompts and file dialogs may follow the operating system language. Official external sources retain their original language.
- App preferences live in the `com.starfolio.wallpaper` domain. Rendered files live under `~/Library/Application Support/Starfolio/rendered`. Referenced wallpaper files are retained so macOS does not lose its wallpaper after the app exits.

## Shared astronomy content

Starfolio is developed and runs independently of [Sightline / 观物志](https://github.com/ykopp/daydream-wallpaper). Neither app needs the other to be running.

`Packages/CelestialKit` is the canonical astronomy content, translations and renderer. Sightline can vendor a versioned snapshot and include its astronomy cards alongside other categories. The shared package now also supplies source discovery, terminology normalization and local-library storage. Sightline currently consumes the bundled astronomy cards; its interface has not yet been connected to Starfolio’s live acquisition workflow. The apps do not share a live user-library folder. Bundled edits and shared code reach Sightline when its snapshot is updated and its app is rebuilt.

```sh
python3 script/sync_sightline.py /path/to/Sightline
python3 script/sync_sightline.py /path/to/Sightline --check
```

See [architecture and editorial workflow](docs/ARCHITECTURE.md) and [verification](docs/VERIFICATION.md).

## Images and licensing

Images retain their original credits and usage terms. Code licensing does not relicense photographs. See [image notices](Packages/CelestialKit/IMAGE_NOTICES.md) and the credit/source panel in the app. Wallpapers are resized/cropped as needed and may carry text overlays; original packaged photographs are unchanged. This project is not affiliated with or endorsed by NASA, ESA, CSA, STScI or ESO.

The three bundled cards remain available offline. Live updates require network access and supported Apple translation languages; they are user-triggered, with no background content schedule. App updates are checked separately and installed manually. There may be no new eligible image on a given check. The acquired library has a 512 MB limit and retains existing files on failure. Favorites, hiding and favorites-only rotation are available; cloud sync is not included. Machine translations, especially Korean, still need independent native-speaker editorial review.
