import Foundation

struct ModelPricing: Codable, Hashable {
    let inputCostPerToken: Double?
    let outputCostPerToken: Double?
    let cacheCreationInputTokenCost: Double?
    let cacheReadInputTokenCost: Double?
    let inputCostPerTokenAbove200kTokens: Double?
    let outputCostPerTokenAbove200kTokens: Double?
    let cacheCreationInputTokenCostAbove200kTokens: Double?
    let cacheReadInputTokenCostAbove200kTokens: Double?

    enum CodingKeys: String, CodingKey {
        case inputCostPerToken = "input_cost_per_token"
        case outputCostPerToken = "output_cost_per_token"
        case cacheCreationInputTokenCost = "cache_creation_input_token_cost"
        case cacheReadInputTokenCost = "cache_read_input_token_cost"
        case inputCostPerTokenAbove200kTokens = "input_cost_per_token_above_200k_tokens"
        case outputCostPerTokenAbove200kTokens = "output_cost_per_token_above_200k_tokens"
        case cacheCreationInputTokenCostAbove200kTokens = "cache_creation_input_token_cost_above_200k_tokens"
        case cacheReadInputTokenCostAbove200kTokens = "cache_read_input_token_cost_above_200k_tokens"
    }
}

struct PricingOverrides: Codable, Hashable {
    let models: [String: ModelPricing]

    private static let providerPrefixes = [
        "anthropic/",
        "claude-3-5-",
        "claude-3-",
        "claude-",
        "openrouter/openai/",
    ]

    func lookup(modelName: String) -> ModelPricing? {
        if let direct = models[modelName] { return direct }
        for prefix in Self.providerPrefixes {
            if let hit = models["\(prefix)\(modelName)"] { return hit }
        }
        let lower = modelName.lowercased()
        for (key, value) in models {
            let cmp = key.lowercased()
            if cmp.contains(lower) || lower.contains(cmp) {
                return value
            }
        }
        return nil
    }
}

enum PricingOverridesLoader {
    static func load(fromPath path: String) throws -> PricingOverrides {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PricingOverrides.self, from: data)
    }

    static let exampleJSON: String = """
    {
      "models": {
        "claude-opus-4-7": {
          "input_cost_per_token": 5e-6,
          "output_cost_per_token": 2.5e-5,
          "cache_creation_input_token_cost": 6.25e-6,
          "cache_read_input_token_cost": 5e-7
        },
        "claude-opus-4-6": {
          "input_cost_per_token": 5e-6,
          "output_cost_per_token": 2.5e-5,
          "cache_creation_input_token_cost": 6.25e-6,
          "cache_read_input_token_cost": 5e-7
        },
        "claude-opus-4-5": {
          "input_cost_per_token": 5e-6,
          "output_cost_per_token": 2.5e-5,
          "cache_creation_input_token_cost": 6.25e-6,
          "cache_read_input_token_cost": 5e-7
        },
        "claude-opus-4-1": {
          "input_cost_per_token": 1.5e-5,
          "output_cost_per_token": 7.5e-5,
          "cache_creation_input_token_cost": 1.875e-5,
          "cache_read_input_token_cost": 1.5e-6
        },
        "claude-sonnet-4-6": {
          "input_cost_per_token": 3e-6,
          "output_cost_per_token": 1.5e-5,
          "cache_creation_input_token_cost": 3.75e-6,
          "cache_read_input_token_cost": 3e-7
        },
        "claude-sonnet-4-5": {
          "input_cost_per_token": 3e-6,
          "output_cost_per_token": 1.5e-5,
          "cache_creation_input_token_cost": 3.75e-6,
          "cache_read_input_token_cost": 3e-7,
          "input_cost_per_token_above_200k_tokens": 6e-6,
          "output_cost_per_token_above_200k_tokens": 2.25e-5,
          "cache_creation_input_token_cost_above_200k_tokens": 7.5e-6,
          "cache_read_input_token_cost_above_200k_tokens": 6e-7
        },
        "claude-haiku-4-5": {
          "input_cost_per_token": 1e-6,
          "output_cost_per_token": 5e-6,
          "cache_creation_input_token_cost": 1.25e-6,
          "cache_read_input_token_cost": 1e-7
        },
        "claude-3-7-sonnet-20250219": {
          "input_cost_per_token": 3e-6,
          "output_cost_per_token": 1.5e-5,
          "cache_creation_input_token_cost": 3.75e-6,
          "cache_read_input_token_cost": 3e-7
        },
        "claude-3-haiku-20240307": {
          "input_cost_per_token": 2.5e-7,
          "output_cost_per_token": 1.25e-6,
          "cache_creation_input_token_cost": 3e-7,
          "cache_read_input_token_cost": 3e-8
        }
      }
    }
    """
}
