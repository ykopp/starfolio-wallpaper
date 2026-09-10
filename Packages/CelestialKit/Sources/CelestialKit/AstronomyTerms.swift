import Foundation

/// Small, source-conditioned corrections for observed machine-translation errors.
/// This does not turn machine translation into editorially reviewed text.
public enum AstronomyTerms {
  public static func normalize(_ translated: String, source: String, language: SkyLanguage)
    -> String
  {
    let english = source.lowercased()
    var result = translated
    if language == .chinese {
      result =
        result.applyingTransform(StringTransform("Traditional-Simplified"), reverse: false)
        ?? result
      if english.range(of: "\\b(galaxy|galaxies|galactic)\\b", options: .regularExpression) != nil,
        !english.contains("milky way"), !english.contains("our galaxy"),
        !english.contains("galactic centre"), !english.contains("galactic center")
      {
        result = result.replacingOccurrences(of: "银河系", with: "星系")
      }
      if english.contains("superbubble") {
        for term in ["超级泡沫", "超级气泡", "超级泡泡"] {
          result = result.replacingOccurrences(of: term, with: "超泡")
        }
      }
      if english.contains("irregular clumps") {
        result = result.replacingOccurrences(of: "不规则的星团", with: "不规则团块")
      }
      if english.contains("field"), !english.contains("magnetic field"),
        !english.contains("electric field")
      {
        result = result.replacingOccurrences(of: "字段", with: "视场")
      }
    } else if language == .korean, english.contains("large magellanic cloud") {
      result = result.replacingOccurrences(of: "대형 마젤란 구름", with: "대마젤란 은하")
    }
    return result
  }
}
