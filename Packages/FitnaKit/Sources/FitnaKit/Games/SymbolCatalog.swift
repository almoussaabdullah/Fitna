import Foundation

/// SF Symbol names used by the visual games. Kept in FitnaKit so generators can
/// reason about visual similarity (symbols in the same family look alike).
/// All are standard SF Symbols available on iOS 17.
public enum SymbolCatalog {
    public struct Entry: Equatable, Sendable {
        public let name: String
        public let family: Int
    }

    /// Objects for أين اختفت؟ and the card faces. Families group look-alikes.
    public static let objects: [Entry] = [
        // 0: nature
        Entry(name: "leaf.fill", family: 0), Entry(name: "tree.fill", family: 0), Entry(name: "camera.macro", family: 0),
        Entry(name: "drop.fill", family: 0), Entry(name: "flame.fill", family: 0),
        // 1: sky
        Entry(name: "sun.max.fill", family: 1), Entry(name: "moon.fill", family: 1), Entry(name: "cloud.fill", family: 1),
        Entry(name: "star.fill", family: 1), Entry(name: "snowflake", family: 1), Entry(name: "bolt.fill", family: 1),
        // 2: animals
        Entry(name: "hare.fill", family: 2), Entry(name: "tortoise.fill", family: 2), Entry(name: "bird.fill", family: 2),
        Entry(name: "fish.fill", family: 2), Entry(name: "ant.fill", family: 2), Entry(name: "pawprint.fill", family: 2),
        // 3: objects
        Entry(name: "key.fill", family: 3), Entry(name: "bell.fill", family: 3), Entry(name: "lightbulb.fill", family: 3),
        Entry(name: "umbrella.fill", family: 3), Entry(name: "gift.fill", family: 3), Entry(name: "cup.and.saucer.fill", family: 3),
        // 4: shapes
        Entry(name: "heart.fill", family: 4), Entry(name: "diamond.fill", family: 4), Entry(name: "triangle.fill", family: 4),
        Entry(name: "hexagon.fill", family: 4), Entry(name: "seal.fill", family: 4), Entry(name: "shield.fill", family: 4),
        // 5: travel
        Entry(name: "car.fill", family: 5), Entry(name: "bicycle", family: 5), Entry(name: "airplane", family: 5),
        Entry(name: "ferry.fill", family: 5), Entry(name: "tram.fill", family: 5), Entry(name: "house.fill", family: 5)
    ]

    /// Card faces for تطابق البطاقات (`CardMatchingEngine.facePoolSize` entries, all clearly distinct).
    public static let cardFaces: [String] = [
        "star.fill", "heart.fill", "moon.fill", "sun.max.fill", "leaf.fill", "bolt.fill", "drop.fill", "flame.fill",
        "bell.fill", "key.fill", "fish.fill", "bird.fill", "gift.fill", "car.fill", "music.note", "crown.fill"
    ]

    /// Directional symbols for rotation differences in صائد الاختلاف (asymmetric under rotation).
    public static let directional: [String] = [
        "arrow.up", "location.north.fill", "hand.point.up.fill", "paperplane.fill", "arrowtriangle.up.fill", "chevron.up"
    ]

    /// Look-alike pairs for symbol-swap differences in صائد الاختلاف (base, odd).
    public static let lookAlikePairs: [(String, String)] = [
        ("circle.fill", "circle.circle.fill"),
        ("square.fill", "square.dashed"),
        ("star.fill", "star.leadinghalf.filled"),
        ("heart.fill", "suit.heart.fill"),
        ("moon.fill", "moon.circle.fill"),
        ("triangle.fill", "arrowtriangle.up.fill"),
        ("cloud.fill", "cloud.drizzle.fill"),
        ("bell.fill", "bell.slash.fill"),
        ("eye.fill", "eye.slash.fill"),
        ("lock.fill", "lock.open.fill")
    ]

    /// Base shapes for أكمل النمط.
    public static let patternShapes: [String] = [
        "circle.fill", "square.fill", "triangle.fill", "diamond.fill", "star.fill", "heart.fill", "hexagon.fill"
    ]
}
