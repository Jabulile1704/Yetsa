import Foundation

/// A line for the morning. Shipped with the app rather than fetched: Yetsa has
/// no network and should not grow one for this.
struct Quote: Hashable, Sendable {
    let text: String
    let author: String
}

enum Quotes {
    /// Mostly voices out of copyright, plus proverbs that belong to everyone.
    /// Weighted towards time, habit and getting on with it, since that is what
    /// the app is about.
    static let all: [Quote] = [
        Quote(text: "It is not that we have a short time to live, but that we waste a lot of it.", author: "Seneca"),
        Quote(text: "Motho ke motho ka batho — a person is a person through other people.", author: "Sesotho proverb"),
        Quote(text: "Begin at once to live, and count each separate day as a separate life.", author: "Seneca"),
        Quote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
        Quote(text: "You could leave life right now. Let that determine what you do and say.", author: "Marcus Aurelius"),
        Quote(text: "However many holy words you read, what good will they do if you do not act on them?", author: "The Dhammapada"),
        Quote(text: "Little strokes fell great oaks.", author: "Benjamin Franklin"),
        Quote(text: "Lost time is never found again.", author: "Benjamin Franklin"),
        Quote(text: "The journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        Quote(text: "Do not wait; the time will never be just right.", author: "Napoleon Hill"),
        Quote(text: "Order your soul. Reduce your wants.", author: "Augustine"),
        Quote(text: "Well begun is half done.", author: "Aristotle"),
        Quote(text: "We are what we repeatedly do. Excellence, then, is not an act but a habit.", author: "Will Durant"),
        Quote(text: "A river cuts through rock not because of its power, but its persistence.", author: "Proverb"),
        Quote(text: "How we spend our days is how we spend our lives.", author: "Annie Dillard"),
        Quote(text: "Nothing is worth more than this day.", author: "Goethe"),
        Quote(text: "The best time to plant a tree was twenty years ago. The second best time is now.", author: "Proverb"),
        Quote(text: "Simplify, simplify.", author: "Henry David Thoreau"),
        Quote(text: "It is not enough to be busy. The question is: what are we busy about?", author: "Henry David Thoreau"),
        Quote(text: "He who has a why to live can bear almost any how.", author: "Friedrich Nietzsche"),
        Quote(text: "Knowing is not enough; we must apply.", author: "Goethe"),
        Quote(text: "If you want to go fast, go alone. If you want to go far, go together.", author: "African proverb"),
        Quote(text: "Smooth seas do not make skilful sailors.", author: "African proverb"),
        Quote(text: "Tomorrow belongs to the people who prepare for it today.", author: "African proverb"),
        Quote(text: "However long the night, the dawn will break.", author: "African proverb"),
        Quote(text: "Patience is bitter, but its fruit is sweet.", author: "Aristotle"),
        Quote(text: "Confine yourself to the present.", author: "Marcus Aurelius"),
        Quote(text: "What we plant in the soil of contemplation, we reap in the harvest of action.", author: "Meister Eckhart"),
        Quote(text: "A year from now you may wish you had started today.", author: "Karen Lamb"),
        Quote(text: "Energy and persistence conquer all things.", author: "Benjamin Franklin"),
        Quote(text: "Make haste slowly.", author: "Augustus"),
        Quote(text: "The man who moves a mountain begins by carrying away small stones.", author: "Confucius"),
        Quote(text: "It does not matter how slowly you go so long as you do not stop.", author: "Confucius"),
        Quote(text: "Each morning we are born again. What we do today matters most.", author: "Buddhist saying"),
        Quote(text: "Whatever you can do, or dream you can, begin it.", author: "Goethe"),
        Quote(text: "Rest is not idleness.", author: "John Lubbock")
    ]

    /// The quote for a given day, chosen from the date itself rather than a
    /// counter. Rescheduling is then idempotent — the same morning always
    /// carries the same line — and the set runs through before repeating.
    static func forDay(_ day: Date, calendar: Calendar) -> Quote {
        let epoch = Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: epoch, to: calendar.startOfDay(for: day)).day ?? 0
        let count = all.count
        return all[((days % count) + count) % count]
    }
}
