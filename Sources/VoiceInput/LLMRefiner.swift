import Foundation

class LLMRefiner {
    static let shared = LLMRefiner()

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "llm_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "llm_enabled") }
    }

    var apiBaseURL: String {
        get { UserDefaults.standard.string(forKey: "llm_api_base_url") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "llm_api_base_url") }
    }

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "llm_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "llm_api_key") }
    }

    var model: String {
        get { UserDefaults.standard.string(forKey: "llm_model") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "llm_model") }
    }

    var isConfigured: Bool {
        !apiBaseURL.isEmpty && !apiKey.isEmpty && !model.isEmpty
    }

    private let systemPrompt = """
    You are a speech recognition post-processor. Your ONLY job is to fix obvious speech recognition errors.

    Rules:
    1. Fix Chinese homophone errors (e.g., 配森→Python, 杰森→JSON, 退步→TensorFlow, 拜森→Python, 死 wan→Swift)
    2. Fix English technical terms that were incorrectly converted to Chinese characters
    3. Fix obvious phonetic mistakes in person names, product names, or technical terms
    4. NEVER rewrite, polish, summarize, or change the meaning of the input
    5. NEVER add or remove content
    6. If the input looks correct, return it EXACTLY as-is
    7. Preserve the original language, tone, and style
    8. Do not add punctuation if it wasn't in the original

    Return ONLY the corrected text, nothing else. No explanation, no quotes.
    """

    func refine(_ text: String) async throws -> String {
        guard !text.isEmpty else { return text }

        let baseURL = apiBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let url = URL(string: "\(baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "max_tokens": max(text.count * 2, 256)
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMError.httpError(statusCode: statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum LLMError: LocalizedError {
        case httpError(statusCode: Int)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .httpError(let code): return "LLM HTTP error: \(code)"
            case .invalidResponse: return "Invalid LLM response"
            }
        }
    }
}
