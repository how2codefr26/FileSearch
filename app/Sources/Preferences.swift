import Foundation

enum ResultDensity:String,Codable,CaseIterable {
    case compact,standard,spacious
    var title:String { self  == .compact ? tr("紧凑型"):self  == .standard ? tr("标准型"):tr("宽松型") }
    var height:Double { self  == .compact ? 36:self  == .standard ? 48:62 }
}
struct Preferences:Codable,Equatable {
    var details=false;var density:ResultDensity = .standard;var desktop=false
    var desktopFrame=""
    var desktopOpacity:Double=0.85
    var desktopGlass=true
    var language:AppLanguage = .simplifiedChinese
    var clampedDesktopOpacity:Double {desktopOpacity.isFinite ? min(1,max(0.3,desktopOpacity)):0.85}
    static func load(from url:URL)->Preferences {(try? JSONDecoder().decode(Preferences.self,from:Data(contentsOf:url))) ?? Preferences()}
    func save(to url:URL)throws{try JSONEncoder().encode(self).write(to:url,options:.atomic)}
}

// Additive settings must preserve older installations' layout and desktop position.
extension Preferences {
    enum CodingKeys:String,CodingKey {case details,density,desktop,desktopFrame,desktopOpacity,desktopGlass,language}
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        details=try c.decodeIfPresent(Bool.self,forKey:.details) ?? false
        density=try c.decodeIfPresent(ResultDensity.self,forKey:.density) ?? .standard
        desktop=try c.decodeIfPresent(Bool.self,forKey:.desktop) ?? false
        desktopFrame=try c.decodeIfPresent(String.self,forKey:.desktopFrame) ?? ""
        desktopOpacity=try c.decodeIfPresent(Double.self,forKey:.desktopOpacity) ?? 0.85
        desktopGlass=try c.decodeIfPresent(Bool.self,forKey:.desktopGlass) ?? true
        language=AppLanguage(rawValue:try c.decodeIfPresent(String.self,forKey:.language) ?? "zh-Hans") ?? .simplifiedChinese
        desktopOpacity=clampedDesktopOpacity
    }
}
