import Foundation

/// Tiny one‑shot helper. No wrappers, no enums.
/// Usage:
/// ```swift
/// OpenAIRequest.send(
///     model: "o4-mini",
///     system: "You are …",
///     user:   "Prompt …",
///     apiKey: key
/// ) { result in … }
/// ```
enum OpenAIRequest {

    static func send(model:  String,
                     system: String,
                     user:   String,
                     apiKey: String,
                     maxTokens: Int = 400,
                     temperature: Double = 0.7,
                     completion: @escaping (Result<String,Error>) -> Void)
    {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions")
        else { completion(.failure(NSError(domain:"URL",code:-1))); return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String:Any] = [
            "model": model,
            "messages": [
                ["role":"system", "content": system],
                ["role":"user",   "content": user  ]
            ],
            "max_tokens":  maxTokens,
            "temperature": temperature
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data,_,error in
            if let error { completion(.failure(error)); return }
            guard
                let data,
                let j = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                let c = j["choices"] as? [[String:Any]],
                let m = c.first?["message"] as? [String:Any],
                let txt = m["content"] as? String
            else { completion(.failure(NSError(domain:"Parse",code:-2))); return }
            completion(.success(txt.trimmingCharacters(in: .whitespacesAndNewlines)))
        }.resume()
    }
}
