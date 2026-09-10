import CelestialKit
import Foundation

enum Copy: String, CaseIterable {
  case today, library, settings, next, previous, apply, pure, knowledge, mode, language, system,
    search, aboutImage, source, rights, close, quit, open, rotation, off, hourly, daily, ready,
    applying, applied, failure, preview, noMatches, selected, release, version, login, loginError,
    displays, retry, noDisplay, export, exportDone, browse, loading
  func text(_ language: SkyLanguage) -> String {
    let words: (String, String, String) =
      switch self {
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
        ("应用 0.1.0 · 天文内容 1.0.0", "App 0.1.0 · Astronomy 1.0.0", "앱 0.1.0 · 천문 콘텐츠 1.0.0")
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
