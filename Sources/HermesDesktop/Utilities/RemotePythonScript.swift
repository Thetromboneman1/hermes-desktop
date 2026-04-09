import Foundation

enum RemotePythonScript {
    static func wrap<Payload: Encodable>(_ payload: Payload, body: String) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        let encodedPayload = data.base64EncodedString()

        return """
        import base64
        import json

        payload = json.loads(base64.b64decode("\(encodedPayload)").decode("utf-8"))

        \(body)
        """
    }
}
