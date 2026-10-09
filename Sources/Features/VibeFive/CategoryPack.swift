import Foundation

/// A single prompt shown on the big card.
struct VibeCategory: Identifiable, Hashable, Sendable {
    let text: String
    let pack: CategoryPack

    var id: String { "\(pack.rawValue)|\(text)" }
}

/// A themed bundle of prompts. Players toggle these on and off in Settings.
///
/// Each pack's prompts live in their own file under `Packs/`, so content can be
/// extended without touching game logic or any other pack.
enum CategoryPack: String, CaseIterable, Identifiable, Hashable, Sendable {
    case everyday
    case food
    case animals
    case movies
    case music
    case tv
    case travel
    case sports
    case games
    case people
    case random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyday: return "Everyday Life"
        case .food: return "Food & Drink"
        case .animals: return "Animals & Nature"
        case .movies: return "Movies & Cinema"
        case .music: return "Music"
        case .tv: return "TV & Streaming"
        case .travel: return "Places & Travel"
        case .sports: return "Sports"
        case .games: return "Games & Play"
        case .people: return "People & Jobs"
        case .random: return "Random & Silly"
        }
    }

    var symbol: String {
        switch self {
        case .everyday: return "house.fill"
        case .food: return "fork.knife"
        case .animals: return "pawprint.fill"
        case .movies: return "film.fill"
        case .music: return "music.note"
        case .tv: return "tv.fill"
        case .travel: return "airplane"
        case .sports: return "figure.run"
        case .games: return "gamecontroller.fill"
        case .people: return "person.2.fill"
        case .random: return "sparkles"
        }
    }

    /// Short line shown under the pack name in Settings.
    var blurb: String {
        switch self {
        case .everyday: return "Kitchens, pockets and junk drawers"
        case .food: return "Meals, snacks and ingredients"
        case .animals: return "Creatures, weather and the outdoors"
        case .movies: return "Films, genres and cinema trips"
        case .music: return "Songs, artists and instruments"
        case .tv: return "Shows, series and streaming"
        case .travel: return "Cities, trips and packing lists"
        case .sports: return "Athletes, matches and the gym"
        case .games: return "Boards, cards, consoles and toys"
        case .people: return "Jobs, habits and awkward moments"
        case .random: return "Daft debates and silly what-ifs"
        }
    }

    /// The raw prompt strings for this pack, defined in `Packs/<Name>Prompts.swift`.
    var prompts: [String] {
        switch self {
        case .everyday: return EverydayPrompts.all
        case .food: return FoodPrompts.all
        case .animals: return AnimalsPrompts.all
        case .movies: return MoviesPrompts.all
        case .music: return MusicPrompts.all
        case .tv: return TVPrompts.all
        case .travel: return TravelPrompts.all
        case .sports: return SportsPrompts.all
        case .games: return GamesPrompts.all
        case .people: return PeoplePrompts.all
        case .random: return RandomPrompts.all
        }
    }

    /// Cheap count that avoids building `VibeCategory` values just to size a list.
    var promptCount: Int { prompts.count }

    var categories: [VibeCategory] {
        prompts.map { VibeCategory(text: $0, pack: self) }
    }
}

enum CategoryLibrary {
    /// Every prompt across every pack.
    static let all: [VibeCategory] = CategoryPack.allCases.flatMap(\.categories)

    static func categories(in packs: Set<CategoryPack>) -> [VibeCategory] {
        guard !packs.isEmpty else { return all }
        return CategoryPack.allCases
            .filter { packs.contains($0) }
            .flatMap(\.categories)
    }

    /// Number of prompts in play, without materialising the categories.
    static func count(in packs: Set<CategoryPack>) -> Int {
        guard !packs.isEmpty else { return all.count }
        return packs.reduce(0) { $0 + $1.promptCount }
    }
}
