// Services/OllamaAPIService.swift
import Foundation

class OllamaAPIService {
    private let baseURL = URL(string: "http://localhost:11434/api")! // Default Ollama API URL
    private let urlSession: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes
        configuration.timeoutIntervalForResource = 300 // 5 minutes
        self.urlSession = URLSession(configuration: configuration)
    }

    // 1. Ollama Detection
    func checkAvailability(completion: @escaping (Bool, Error?) -> Void) {
        let url = baseURL.appendingPathComponent("tags") // A lightweight endpoint to check
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, error)
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                completion(false, NSError(domain: "OllamaServiceError", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
                return
            }
            // Optionally parse OllamaTagsResponse here if you want to use it
            completion(true, nil)
        }.resume()
    }

    // 2. Basic Prompting (Raw Text Response)
    func generateRawOrganizationSuggestion(fileNames: [String], modelName: String, systemPrompt: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        let url = baseURL.appendingPathComponent("generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // V1 Prompt: Simple list of filenames
        let promptContent = "Here is a list of filenames: \(fileNames.joined(separator: ", ")). Group them into semantic folders. For each proposed folder, state the folder name and then list the files that belong in it. Be concise."

        let payload = OllamaGenerateRequest(model: modelName, prompt: promptContent)
                                            // system: systemPrompt) // If you add system prompt support

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            completion(.failure(error))
            return
        }

        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "OllamaServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTPURLResponse."])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "OllamaServiceError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received."])))
                return
            }

            do {
                if httpResponse.statusCode == 200 {
                    let ollamaResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
                    completion(.success(ollamaResponse.response))
                } else {
                    // Try to decode an error response
                    let errorResponse = try JSONDecoder().decode(OllamaErrorResponse.self, from: data)
                    completion(.failure(NSError(domain: "OllamaAPIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])))
                }
            } catch {
                // If JSON decoding fails, return raw data as string for debugging if possible, or the decoding error
                if let dataString = String(data: data, encoding: .utf8) {
                     completion(.failure(NSError(domain: "OllamaServiceError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON. Raw: \(dataString). Error: \(error.localizedDescription)"])))
                } else {
                     completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func generateStructuredOrganizationPlan(fileNames: [String], existingFolderStructure: [String]?, modelName: String, systemPrompt: String? = nil, completion: @escaping (Result<[ProposedFileSystemChange], Error>) -> Void) {
        let url = baseURL.appendingPathComponent("generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // V2 Prompt: Instruct for JSON output
        // This will need a LOT of iteration.
        var promptContent = """
        You are an AI file organization assistant. Your task is to organize the following list of files into semantic folders.
        The list of files is: \(fileNames.joined(separator: ", ")).
        """
        if let existingFolders = existingFolderStructure, !existingFolders.isEmpty {
            promptContent += "\nThe current folder already contains these subfolders: \(existingFolders.joined(separator: ", ")). You can suggest moving files into these existing folders or creating new ones."
        }
        promptContent += """

        Respond ONLY with a valid JSON array. Each object in the array represents a folder (either new or existing) and the files that should be in it.
        Each JSON object MUST have the following keys:
        - "folderName": A string representing the name of the target folder. If it's a new folder, provide a descriptive name. If it's an existing subfolder, use its exact name.
        - "filesToMove": An array of strings, where each string is an exact filename from the provided list that should be moved into this folder.
        - "isNewFolder": A boolean (true or false). Set to true if this "folderName" is a new folder you are proposing. Set to false if "folderName" is one of the existing subfolders.

        Do NOT include any explanations, introductory text, or markdown formatting outside of the JSON array itself.
        The entire response must be a single, valid JSON array.

        Example of a valid JSON response:
        [
            {
                "folderName": "Project Reports Q3",
                "filesToMove": ["report_final_v2.docx", "data_summary_q3.xlsx"],
                "isNewFolder": true
            },
            {
                "folderName": "Existing Folder/Images",
                "filesToMove": ["logo.png", "banner_ad.jpg"],
                "isNewFolder": false
            }
        ]
        """
        // For few-shot learning (MVP-Basic for learning from existing structure, as per spec 2.3)
        // You might inject examples of *your* desired organization here if `existingFolderStructure` is rich.

        let payload = OllamaGenerateRequest(model: modelName, prompt: promptContent /*, system: systemPrompt */)

        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            completion(.failure(error))
            return
        }

        urlSession.dataTask(with: request) { data, response, error in
            // ... (error handling similar to generateRawOrganizationSuggestion)
            // CRITICAL: Parse into [ProposedFileSystemChange].self
            if let error = error { completion(.failure(error)); return }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "OllamaServiceError", code: -1, userInfo: [NSLocalizedDescriptionKey: "No HTTPURLResponse."])))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "OllamaServiceError", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received."])))
                return
            }

            do {
                if httpResponse.statusCode == 200 {
                    let ollamaRawResponse = try JSONDecoder().decode(OllamaGenerateResponse.self, from: data)
                    
                    // Extract only the JSON array from the LLM's response string
                    // Extract only the JSON array from the LLM's response string, handling markdown code blocks
                    // Extract only the JSON array from the LLM's response string, handling markdown code blocks
                    // This regex is more robust to potential whitespace variations around the JSON content.
                    guard let regex = try? NSRegularExpression(pattern: "```json\\s*([\\s\\S]*?)\\s*```", options: []),
                          let match = regex.firstMatch(in: ollamaRawResponse.response, options: [], range: NSRange(location: 0, length: ollamaRawResponse.response.utf16.count)) else {
                        let rawResponseString = String(data: data, encoding: .utf8) ?? "Undecodable data"
                        completion(.failure(NSError(domain: "OllamaServiceError", code: -4, userInfo: [NSLocalizedDescriptionKey: "LLM response did not contain a valid JSON array within markdown. Raw: \(rawResponseString)"])))
                        return
                    }
                    
                    // The captured group (index 1) contains the actual JSON string
                    let jsonString = (ollamaRawResponse.response as NSString).substring(with: match.range(at: 1))
                    
                    guard let jsonData = jsonString.data(using: .utf8) else {
                        completion(.failure(NSError(domain: "OllamaServiceError", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to convert extracted JSON string to Data."])))
                        return
                    }
                    
                    let plan = try JSONDecoder().decode([ProposedFileSystemChange].self, from: jsonData)
                    completion(.success(plan))
                } else {
                    let errorResponse = try JSONDecoder().decode(OllamaErrorResponse.self, from: data)
                    completion(.failure(NSError(domain: "OllamaAPIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse.error])))
                }
            } catch {
                 // More detailed error logging for JSON parsing failures
                let rawResponseString = String(data: data, encoding: .utf8) ?? "Undecodable data"
                print("Failed to decode JSON. LLM Response was: \(rawResponseString)")
                completion(.failure(NSError(domain: "OllamaServiceError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse structured JSON response from LLM. Raw: \(rawResponseString). Error: \(error.localizedDescription)"])))
            }
        }.resume()
    }
}