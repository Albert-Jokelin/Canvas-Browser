import Foundation

/// Classifies browsing intent and determines when to suggest GenTabs
class IntentClassifier {

    // MARK: - Analysis Result

    struct Analysis {
        let shouldSuggestGenTab: Bool
        let confidence: Double
        let suggestedTitle: String?
        let relatedTabIds: [UUID]
        let reason: String
        let detectedCategory: ContentCategory?
    }

    enum ContentCategory: String {
        case shopping = "Shopping & Products"
        case travel = "Travel Planning"
        case research = "Research & Learning"
        case recipes = "Recipes & Cooking"
        case news = "News & Articles"
        case comparison = "Product Comparison"
        case entertainment = "Entertainment"
        case utility = "Utility & Tools"
        case unknown = "Unknown"
    }

    // MARK: - Domain Lists

    /// Domains where GenTab suggestions should be suppressed
    private let excludedDomains = [
        // Entertainment
        "youtube.com", "netflix.com", "hulu.com", "disneyplus.com",
        "twitch.tv", "spotify.com", "soundcloud.com",
        // Social Media
        "twitter.com", "x.com", "facebook.com", "instagram.com",
        "tiktok.com", "reddit.com", "linkedin.com", "threads.net",
        // Email & Communication
        "gmail.com", "mail.google.com", "outlook.com", "outlook.live.com",
        "mail.yahoo.com", "proton.me", "slack.com", "discord.com",
        // Banking & Finance (sensitive)
        "chase.com", "bankofamerica.com", "wellsfargo.com", "paypal.com",
        // Utility
        "google.com/search", "bing.com/search", "duckduckgo.com"
    ]

    /// Domains that strongly indicate shopping intent
    private let shoppingDomains = [
        "amazon.com", "ebay.com", "walmart.com", "target.com",
        "bestbuy.com", "costco.com", "newegg.com", "homedepot.com",
        "lowes.com", "etsy.com", "wayfair.com", "aliexpress.com",
        "shopify.com", "apple.com/shop"
    ]

    /// Domains that strongly indicate travel intent
    private let travelDomains = [
        "booking.com", "expedia.com", "hotels.com", "airbnb.com",
        "kayak.com", "tripadvisor.com", "southwest.com", "united.com",
        "delta.com", "aa.com", "vrbo.com", "hostelworld.com",
        "google.com/travel", "google.com/flights"
    ]

    /// Domains that indicate recipe/cooking intent
    private let recipeDomains = [
        "allrecipes.com", "foodnetwork.com", "epicurious.com",
        "bonappetit.com", "seriouseats.com", "tasty.co",
        "delish.com", "simplyrecipes.com", "food52.com"
    ]

    // MARK: - Main Analysis

    func analyze(contents: [ContentExtractor.ExtractedContent]) async -> Analysis {
        // Rule 1: Need at least 2 tabs for meaningful analysis
        guard contents.count >= 2 else {
            return Analysis(
                shouldSuggestGenTab: false,
                confidence: 0,
                suggestedTitle: nil,
                relatedTabIds: [],
                reason: "Not enough tabs open",
                detectedCategory: nil
            )
        }

        // Rule 2: Check for excluded domains
        let dominantDomain = findDominantDomain(contents)
        if isExcludedDomain(dominantDomain) {
            return Analysis(
                shouldSuggestGenTab: false,
                confidence: 0,
                suggestedTitle: nil,
                relatedTabIds: [],
                reason: "Browsing entertainment or utility sites",
                detectedCategory: .entertainment
            )
        }

        // Rule 3: Detect specific intent categories
        if let shoppingAnalysis = detectShoppingIntent(contents) {
            return shoppingAnalysis
        }

        if let travelAnalysis = detectTravelIntent(contents) {
            return travelAnalysis
        }

        if let recipeAnalysis = detectRecipeIntent(contents) {
            return recipeAnalysis
        }

        // Rule 4: Detect general research intent (3+ tabs on similar topic)
        if let researchAnalysis = detectResearchIntent(contents) {
            return researchAnalysis
        }

        // No clear intent detected
        return Analysis(
            shouldSuggestGenTab: false,
            confidence: 0.3,
            suggestedTitle: nil,
            relatedTabIds: contents.map { $0.tabId },
            reason: "No clear browsing pattern detected",
            detectedCategory: .unknown
        )
    }

    // MARK: - Intent Detection Methods

    private func detectShoppingIntent(_ contents: [ContentExtractor.ExtractedContent]) -> Analysis? {
        let shoppingTabs = contents.filter { content in
            shoppingDomains.contains(where: { content.domain.contains($0) }) ||
            content.textContent.lowercased().contains("add to cart") ||
            content.textContent.lowercased().contains("buy now") ||
            content.textContent.contains("$")
        }

        guard shoppingTabs.count >= 2 else { return nil }

        // Check if they're looking at similar products
        let confidence = min(Double(shoppingTabs.count) / 4.0, 1.0)

        return Analysis(
            shouldSuggestGenTab: true,
            confidence: confidence,
            suggestedTitle: "Product Comparison",
            relatedTabIds: shoppingTabs.map { $0.tabId },
            reason: "Detected \(shoppingTabs.count) shopping tabs",
            detectedCategory: .shopping
        )
    }

    private func detectTravelIntent(_ contents: [ContentExtractor.ExtractedContent]) -> Analysis? {
        let travelTabs = contents.filter { content in
            travelDomains.contains(where: { content.domain.contains($0) }) ||
            content.textContent.lowercased().contains("flight") ||
            content.textContent.lowercased().contains("hotel") ||
            content.textContent.lowercased().contains("booking")
        }

        guard travelTabs.count >= 2 else { return nil }

        let confidence = min(Double(travelTabs.count) / 3.0, 1.0)

        return Analysis(
            shouldSuggestGenTab: true,
            confidence: confidence,
            suggestedTitle: "Trip Planner",
            relatedTabIds: travelTabs.map { $0.tabId },
            reason: "Detected \(travelTabs.count) travel-related tabs",
            detectedCategory: .travel
        )
    }

    private func detectRecipeIntent(_ contents: [ContentExtractor.ExtractedContent]) -> Analysis? {
        let recipeTabs = contents.filter { content in
            recipeDomains.contains(where: { content.domain.contains($0) }) ||
            content.textContent.lowercased().contains("ingredients") ||
            content.textContent.lowercased().contains("recipe")
        }

        guard recipeTabs.count >= 2 else { return nil }

        let confidence = min(Double(recipeTabs.count) / 3.0, 1.0)

        return Analysis(
            shouldSuggestGenTab: true,
            confidence: confidence,
            suggestedTitle: "Recipe Collection",
            relatedTabIds: recipeTabs.map { $0.tabId },
            reason: "Detected \(recipeTabs.count) recipe tabs",
            detectedCategory: .recipes
        )
    }

    private func detectResearchIntent(_ contents: [ContentExtractor.ExtractedContent]) -> Analysis? {
        // Need at least 3 tabs for research intent
        guard contents.count >= 3 else { return nil }

        // Find common keywords across tabs
        let allText = contents.map { $0.textContent.lowercased() }.joined(separator: " ")
        let words = allText.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.count > 5 } // Only consider longer words

        // Count word frequency
        var wordCounts: [String: Int] = [:]
        for word in words {
            wordCounts[word, default: 0] += 1
        }

        // Find words that appear in multiple tabs
        let commonWords = wordCounts.filter { $0.value >= contents.count - 1 }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        guard !commonWords.isEmpty else { return nil }

        // Check if multiple tabs share common themes
        let topic = commonWords.first?.capitalized ?? "Research"

        return Analysis(
            shouldSuggestGenTab: true,
            confidence: 0.7,
            suggestedTitle: "\(topic) Summary",
            relatedTabIds: contents.map { $0.tabId },
            reason: "Found common topic: \(commonWords.joined(separator: ", "))",
            detectedCategory: .research
        )
    }

    // MARK: - Helper Methods

    private func findDominantDomain(_ contents: [ContentExtractor.ExtractedContent]) -> String {
        var domainCounts: [String: Int] = [:]
        for content in contents {
            let baseDomain = extractBaseDomain(content.domain)
            domainCounts[baseDomain, default: 0] += 1
        }
        return domainCounts.max(by: { $0.value < $1.value })?.key ?? ""
    }

    private func extractBaseDomain(_ domain: String) -> String {
        // Remove www. prefix and get base domain
        var base = domain.lowercased()
        if base.hasPrefix("www.") {
            base = String(base.dropFirst(4))
        }
        return base
    }

    private func isExcludedDomain(_ domain: String) -> Bool {
        let baseDomain = extractBaseDomain(domain)
        return excludedDomains.contains(where: { baseDomain.contains($0) })
    }
}
