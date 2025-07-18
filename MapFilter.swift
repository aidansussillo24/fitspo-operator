
import Foundation

struct MapFilter: Equatable {
    enum Weather: String, CaseIterable { case sunny, cloudy }
    enum TempBand: String, CaseIterable { case cold, cool, warm, hot }

    var weather: Weather? = nil
    var tempBand: TempBand? = nil
    var season: ExploreFilter.Season? = nil
}
