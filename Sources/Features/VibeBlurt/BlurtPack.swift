import Foundation

/// A themed bundle of things to describe. Players toggle these on and off
/// before a game starts.
enum BlurtPack: String, CaseIterable, Identifiable, Hashable, Sendable {
    case food
    case animals
    case places
    case household
    case people
    case play
    case actions
    case occasions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food & Drink"
        case .animals: return "Animals & Nature"
        case .places: return "Places & Travel"
        case .household: return "Household Objects"
        case .people: return "Jobs & People"
        case .play: return "Sport & Music"
        case .actions: return "Actions & Situations"
        case .occasions: return "Celebrations & Weather"
        }
    }

    /// An SF Symbol name that exists on iOS 17.
    var symbol: String {
        switch self {
        case .food: return "fork.knife"
        case .animals: return "pawprint.fill"
        case .places: return "map.fill"
        case .household: return "house.fill"
        case .people: return "person.2.fill"
        case .play: return "sportscourt.fill"
        case .actions: return "figure.walk"
        case .occasions: return "party.popper.fill"
        }
    }

    /// One short line describing the pack, shown under the title.
    var blurb: String {
        switch self {
        case .food: return "Meals, snacks and drinks"
        case .animals: return "Creatures great and small"
        case .places: return "Spots near and far"
        case .household: return "Things around the home"
        case .people: return "Jobs and the people who do them"
        case .play: return "Sports, games and music"
        case .actions: return "Things people do"
        case .occasions: return "Festivals, celebrations and weather"
        }
    }

    var words: [String] {
        switch self {
        case .food: return FoodWords.all
        case .animals: return AnimalsWords.all
        case .places: return PlacesWords.all
        case .household: return HouseholdWords.all
        case .people: return PeopleWords.all
        case .play: return PlayWords.all
        case .actions: return ActionsWords.all
        case .occasions: return OccasionsWords.all
        }
    }
}
