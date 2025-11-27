import Foundation
import TheMet

struct SearchFilters: Equatable {
    var departmentId: Int?
    var requiresImages = true
    var highlightsOnly = false
    var onViewOnly = false
    var artistOrCultureOnly = false
    var medium = ""
    var geoLocation = ""
    var dateBegin = ""
    var dateEnd = ""

    var parsedDateBegin: Int? {
        Int(dateBegin.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var parsedDateEnd: Int? {
        Int(dateEnd.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func departmentName(from departments: [Department]) -> String? {
        guard let departmentId else { return nil }
        return departments.first { $0.departmentId == departmentId }?.displayName
    }

    func toMetFilters(searchTerm: String) -> [MetFilter] {
        var filters: [MetFilter] = [.searchTerm(searchTerm)]

        if let departmentId {
            filters.append(.departmentId(departmentId))
        }
        if requiresImages {
            filters.append(.hasImages(true))
        }
        if highlightsOnly {
            filters.append(.isHighlight(true))
        }
        if onViewOnly {
            filters.append(.isOnView(true))
        }
        if artistOrCultureOnly {
            filters.append(.artistOrCulture(true))
        }
        if let parsedDateBegin {
            filters.append(.dateBegin(parsedDateBegin))
        }
        if let parsedDateEnd {
            filters.append(.dateEnd(parsedDateEnd))
        }

        let medium = medium.trimmingCharacters(in: .whitespacesAndNewlines)
        if medium.isEmpty == false {
            filters.append(.medium(medium))
        }

        let geoLocation = geoLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if geoLocation.isEmpty == false {
            filters.append(.geoLocation(geoLocation))
        }

        return filters
    }

    static var `default`: SearchFilters { SearchFilters() }
}
