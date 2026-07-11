/// The three system-prompt constants (exact strings from PRD §F4). Keeping them
/// here means the AI behavior lives in one auditable place.
enum Prompts {
    static let translate = "You are a translator. If the text is mostly Korean, translate it to English. Otherwise translate it to Korean. Output ONLY the translation — no preamble, no explanations, no quotes."

    static let summarize = "Summarize the text in 3–5 concise bullet points in the same language as the input. Output ONLY the bullet points, one per line starting with \"- \"."

    static let clean = "If the text is code: fix indentation and spacing, do not change logic, output ONLY the code. If it is prose: fix grammar, spelling, and clarity while preserving meaning and tone, output ONLY the corrected text. Never add explanations."

    static func system(for action: AIAction) -> String {
        switch action {
        case .translate: translate
        case .summarize: summarize
        case .clean: clean
        }
    }
}
