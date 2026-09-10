import CelestialKit
import Foundation

enum Copy: String, CaseIterable {
  case today, library, settings, next, previous, apply, pure, knowledge, mode, language, system,
    search, aboutImage, source, rights, close, quit, open, rotation, off, hourly, daily, ready,
    applying, applied, failure, preview, noMatches, selected, release, version, login, loginError,
    displays, retry, noDisplay, export, exportDone, browse, loading
  case showNew, allImages
  case update, updateReady, finding, translating, makingCards, updateDone, updateEmpty,
    updateCancelled, updateFailed, translationFailed, libraryFull, libraryWarning, cancelUpdate,
    newCard, updateHint, updateSkipped
  func text(_ language: SkyLanguage) -> String {
    let words: (String, String, String) =
      switch self {
      case .showNew: ("查看新增", "View new", "새 콘텐츠 보기")
      case .allImages: ("全部图片", "All images", "모든 이미지")
      case .update: ("内容更新", "Get new content", "콘텐츠 업데이트")
      case .updateReady:
        ("获取新图并制作三语言卡片", "Find images and make trilingual cards", "새 이미지와 3개 언어 카드 만들기")
      case .finding: ("正在寻找并下载新图片…", "Finding and downloading images…", "새 이미지 검색 및 다운로드 중…")
      case .translating: ("正在制作中英韩知识…", "Preparing three-language notes…", "3개 언어 설명 준비 중…")
      case .makingCards: ("正在生成壁纸并保存…", "Rendering and saving wallpapers…", "배경화면 생성 및 저장 중…")
      case .updateDone: ("新内容已加入图库", "New content added to your library", "새 콘텐츠가 도감에 추가되었습니다")
      case .updateEmpty:
        (
          "本次没有可加入的新内容，可稍后再试", "No eligible new content this time. Try again later.",
          "지금은 추가할 새 콘텐츠가 없습니다. 나중에 다시 시도해 주세요."
        )
      case .updateCancelled:
        ("已取消，原有图库保持完整", "Cancelled. Existing content is intact.", "취소되었습니다. 기존 콘텐츠는 유지됩니다.")
      case .updateFailed:
        (
          "获取或保存未完成，请重试", "Could not fetch or save content. Please retry.",
          "업데이트하지 못했습니다. 연결을 확인한 뒤 다시 시도해 주세요."
        )
      case .translationFailed:
        (
          "翻译未完成，请允许系统下载语言包后重试", "Translation failed. Allow system language downloads and retry.",
          "번역하지 못했습니다. 시스템 언어 다운로드를 허용한 뒤 다시 시도해 주세요."
        )
      case .libraryFull:
        (
          "下载内容已达到本机容量上限", "Downloaded content reached the local storage limit",
          "다운로드 콘텐츠가 저장 용량 한도에 도달했습니다"
        )
      case .libraryWarning:
        (
          "部分已下载内容无法读取，原文件已保留", "Some downloaded content could not be read. Files were preserved.",
          "일부 콘텐츠를 읽을 수 없습니다. 원본 파일은 보존되었습니다."
        )
      case .cancelUpdate: ("取消更新", "Cancel update", "업데이트 취소")
      case .newCard: ("新增", "New", "새 콘텐츠")
      case .updateHint:
        (
          "每次最多加入 3 张；加入后可手动更换或参与轮播",
          "Up to 3 images per update. Choose one or include them in rotation.",
          "한 번에 최대 3장을 추가합니다. 직접 선택하거나 자동 변경으로 감상하세요."
        )
      case .updateSkipped:
        (
          "部分候选未通过筛选或暂时无法获取", "Some candidates were filtered out or unavailable",
          "일부 후보는 필터링되었거나 가져올 수 없습니다"
        )
      case .today: ("今日宇宙", "Today’s universe", "오늘의 우주")
      case .library: ("星空图鉴", "Sky library", "별빛 도감")
      case .settings: ("设置", "Settings", "설정")
      case .next: ("下一张", "Next", "다음")
      case .previous: ("上一张", "Previous", "이전")
      case .apply: ("设为壁纸", "Set wallpaper", "배경화면으로 설정")
      case .pure: ("纯图", "Image only", "이미지만")
      case .knowledge: ("轻知识", "With captions", "짧은 설명")
      case .mode: ("壁纸文字", "Wallpaper text", "배경화면 설명")
      case .language: ("语言", "Language", "언어")
      case .system: ("跟随系统", "System language", "시스템 언어")
      case .search: ("搜索天体或主题", "Search objects or topics", "천체나 주제 검색")
      case .aboutImage: ("了解这张图", "About this image", "이미지 알아보기")
      case .source: ("官方原图与说明", "Official image & description", "공식 이미지와 설명")
      case .rights: ("图像署名与使用规则", "Image credits & usage", "이미지 출처와 이용 안내")
      case .close: ("关闭", "Close", "닫기")
      case .quit: ("退出 Starfolio", "Quit Starfolio", "Starfolio 종료")
      case .open: ("打开 Starfolio", "Open Starfolio", "Starfolio 열기")
      case .rotation: ("自动换图", "Automatic rotation", "자동 변경")
      case .off: ("关闭", "Off", "끔")
      case .hourly: ("每小时", "Every hour", "매시간")
      case .daily: ("每天", "Every day", "매일")
      case .ready:
        ("选择一张图片，开始探索宇宙。", "Choose an image and explore the universe.", "이미지를 선택하고 우주를 탐험해 보세요.")
      case .applying: ("正在设置壁纸…", "Setting wallpaper…", "배경화면 설정 중…")
      case .applied: ("壁纸已更新", "Wallpaper updated", "배경화면이 변경되었습니다")
      case .failure: ("未能完成，请重试", "Could not complete. Please retry.", "완료하지 못했습니다. 다시 시도해 주세요.")
      case .preview: ("预览模式 · 不更改桌面", "Preview mode · Desktop unchanged", "미리보기 · 배경화면은 변경되지 않습니다")
      case .noMatches: ("没有匹配内容", "No matching images", "일치하는 이미지가 없습니다")
      case .selected: ("当前选择", "Selected", "선택됨")
      case .release: ("暂停换图", "Pause rotation", "자동 변경 일시 정지")
      case .version:
        ("应用 0.2.0 · 天文内容 1.1.0", "App 0.2.0 · Astronomy 1.1.0", "앱 0.2.0 · 천문 콘텐츠 1.1.0")
      case .login: ("登录时启动", "Launch at login", "로그인 시 실행")
      case .loginError:
        ("请在系统设置中检查登录项目权限", "Check Login Items in System Settings.", "시스템 설정에서 로그인 항목 권한을 확인하세요.")
      case .displays: ("显示器", "Displays", "디스플레이")
      case .retry: ("重试", "Retry", "다시 시도")
      case .noDisplay: ("没有可用显示器", "No available display", "사용 가능한 디스플레이가 없습니다")
      case .export: ("导出壁纸", "Export wallpaper", "배경화면 내보내기")
      case .exportDone: ("壁纸已导出", "Wallpaper exported", "배경화면을 내보냈습니다")
      case .browse:
        (
          "浏览图片不会更改桌面；点击“设为壁纸”后应用。",
          "Browsing keeps your desktop unchanged. Use Set wallpaper to apply.",
          "이미지를 둘러보는 동안 배경화면은 바뀌지 않습니다. 설정 버튼을 눌러 적용하세요."
        )
      case .loading: ("正在生成预览…", "Preparing preview…", "미리보기 준비 중…")
      }
    switch language {
    case .chinese: return words.0
    case .english: return words.1
    case .korean: return words.2
    }
  }
}
