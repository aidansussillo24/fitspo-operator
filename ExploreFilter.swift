//
//  ExploreFilter.swift
//  FitSpo
//

import Foundation

struct ExploreFilter: Equatable {

    enum Season:   String, CaseIterable { case spring, summer, fall, winter }
    enum TimeBand: String, CaseIterable { case morning, afternoon, evening, night }

    var season:   Season?   = nil        // nil = “any”
    var timeBand: TimeBand? = nil
}
