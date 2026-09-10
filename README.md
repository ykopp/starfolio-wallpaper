# 星笺 · Starfolio · 스타폴리오

A quiet, native macOS wallpaper app for astronomy. Real observations, a little knowledge, and a clear path back to the source.

![星笺中文界面](docs/screenshots/chinese.jpg)

## 内容更新 / Content update / 콘텐츠 업데이트

**中文：** 独立的 macOS 星空壁纸应用。中文、英文、韩文覆盖应用内界面、壁纸短文和知识详情；支持跟随系统或手动切换。内置宇宙悬崖、土星与它的环、帕拉纳尔银河三张精选图片，可离线浏览、搜索、切换纯图与轻知识、设置壁纸、导出 PNG、按小时或每日轮换，以及登录时启动。浏览图片不会立即换桌面。

**English:** An independent macOS astronomy wallpaper app with Chinese, English and Korean interfaces, captions and reading notes. Three curated images work offline: Cosmic Cliffs, Saturn & Its Rings, and Milky Way over Paranal. Browse and search, switch between image-only and short-caption wallpapers, apply to connected displays, export PNG, rotate hourly or daily, and launch at login. Browsing alone does not change the desktop.

**한국어:** 중국어·영어·한국어 인터페이스와 설명을 제공하는 독립형 macOS 천문 배경화면 앱입니다. 우주의 절벽, 토성과 고리, 파라날의 은하수 등 세 가지 엄선된 이미지를 오프라인으로 감상할 수 있습니다. 검색, 이미지 전용 모드와 짧은 설명 모드, 배경화면 설정, PNG 내보내기, 시간별·일별 자동 변경, 로그인 시 실행을 지원합니다. 이미지를 둘러보는 것만으로는 배경화면이 바뀌지 않습니다.

## 点击「内容更新」会发生什么

应用会从 ESA/Webb 与 ESA/Hubble 官方近期图片中筛选真实天文观测，下载图片和说明，选取完整原文段落，使用 Apple 本机翻译制作中英韩内容，再生成壁纸并加入本机图库。每次最多新增 3 张；重复图片会跳过。使用「查看新增」挑选，再设置壁纸或开启每小时／每日轮播。更新不会改变当前选图或立即替换桌面。

首次制作可能需要同意 macOS 下载翻译语言。新增中文和韩文会标明机器翻译，英文保留官方原文，并附来源、完整图片署名和使用条款。下载完成后可离线使用；这不是无人审核的生成式天文知识。少量已发现的天文术语误译会按原文校正，仍可能存在其他翻译错误。

**English:** Click **Content update** to discover recent ESA/Webb and ESA/Hubble observations, download images and source excerpts, translate them on device into Chinese and Korean, render wallpapers, and add up to three cards to your local library. **View new** filters the additions; you choose what to apply or include in rotation. macOS may ask to download translation languages. New translations are labeled as machine translated and retain source links and credits.

**한국어:** **콘텐츠 업데이트**를 누르면 ESA/Webb와 ESA/Hubble의 최근 관측 이미지를 찾아 다운로드하고, 공식 설명을 기기에서 번역해 한 번에 최대 세 개의 콘텐츠를 보관함에 추가합니다. **새 콘텐츠 보기**에서 고른 뒤 배경화면으로 설정하거나 자동 변경을 켤 수 있습니다. 업데이트만으로 현재 배경화면이 바뀌지는 않습니다. 처음에는 macOS가 번역 언어 다운로드 동의를 요청할 수 있습니다. 기계 번역 표시와 원문 출처·이미지 크레딧이 함께 제공됩니다.

## Run locally

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

The three bundled cards remain available offline. Live updates require network access and supported Apple translation languages; they are user-triggered, with no background schedule or app auto-updater. There may be no new eligible image on a given check. The acquired library has a 512 MB limit and retains existing files on failure. Favorites and cloud sync are not included. Machine translations, especially Korean, still need independent native-speaker editorial review.
