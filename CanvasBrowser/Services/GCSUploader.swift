import Foundation
import CryptoKit

enum GCSError: LocalizedError {
    case missingCredentials
    case bucketNotConfigured
    case uploadFailed(statusCode: Int, body: String)
    case deleteFailed(statusCode: Int, body: String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "GCS credentials not configured. Please add your Access Key ID and Secret in Settings > Cloud Storage."
        case .bucketNotConfigured:
            return "GCS bucket name not configured. Please enter your bucket name in Settings > Cloud Storage."
        case .uploadFailed(let code, let body):
            return "Upload failed (HTTP \(code)): \(body)"
        case .deleteFailed(let code, let body):
            return "Delete failed (HTTP \(code)): \(body)"
        case .invalidURL:
            return "Could not construct a valid GCS URL."
        }
    }
}

struct GCSUploader {
    static var accessKeyID: String { UserDefaults.standard.string(forKey: "gcsAccessKeyID") ?? "" }
    static var secretKey: String   { UserDefaults.standard.string(forKey: "gcsSecretKey")   ?? "" }
    static var bucketName: String  { UserDefaults.standard.string(forKey: "gcsBucketName")  ?? "" }

    static var isConfigured: Bool {
        !accessKeyID.isEmpty && !secretKey.isEmpty && !bucketName.isEmpty
    }

    /// Upload `data` to GCS and return the public URL.
    static func upload(data: Data, objectKey: String, contentType: String) async throws -> URL {
        guard !accessKeyID.isEmpty && !secretKey.isEmpty else { throw GCSError.missingCredentials }
        guard !bucketName.isEmpty else { throw GCSError.bucketNotConfigured }

        let urlString = "https://storage.googleapis.com/\(bucketName)/\(objectKey)"
        guard let url = URL(string: urlString) else { throw GCSError.invalidURL }

        let dateString = rfc2616Date()
        let signature = try hmacSHA256Base64(
            key: secretKey,
            message: "PUT\n\n\(contentType)\n\(dateString)\n/\(bucketName)/\(objectKey)"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = data
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(dateString, forHTTPHeaderField: "Date")
        request.setValue("GOOG1 \(accessKeyID):\(signature)", forHTTPHeaderField: "Authorization")
        request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        guard (200...299).contains(statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? "(no body)"
            throw GCSError.uploadFailed(statusCode: statusCode, body: body)
        }

        guard let publicURL = URL(string: urlString) else { throw GCSError.invalidURL }
        return publicURL
    }

    /// Delete an object from GCS.
    static func delete(objectKey: String) async throws {
        guard !accessKeyID.isEmpty && !secretKey.isEmpty else { throw GCSError.missingCredentials }
        guard !bucketName.isEmpty else { throw GCSError.bucketNotConfigured }

        let urlString = "https://storage.googleapis.com/\(bucketName)/\(objectKey)"
        guard let url = URL(string: urlString) else { throw GCSError.invalidURL }

        let dateString = rfc2616Date()
        let signature = try hmacSHA256Base64(
            key: secretKey,
            message: "DELETE\n\n\n\(dateString)\n/\(bucketName)/\(objectKey)"
        )

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(dateString, forHTTPHeaderField: "Date")
        request.setValue("GOOG1 \(accessKeyID):\(signature)", forHTTPHeaderField: "Authorization")

        let (responseData, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        // 204 No Content is the success response for DELETE; 404 means already gone — both are fine.
        guard (200...299).contains(statusCode) || statusCode == 404 else {
            let body = String(data: responseData, encoding: .utf8) ?? "(no body)"
            throw GCSError.deleteFailed(statusCode: statusCode, body: body)
        }
    }

    // MARK: - Private helpers

    private static func rfc2616Date() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter.string(from: Date())
    }

    private static func hmacSHA256Base64(key: String, message: String) throws -> String {
        guard let keyData = key.data(using: .utf8),
              let messageData = message.data(using: .utf8) else {
            throw GCSError.missingCredentials
        }
        let symmetricKey = SymmetricKey(data: keyData)
        let mac = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        return Data(mac).base64EncodedString()
    }
}
