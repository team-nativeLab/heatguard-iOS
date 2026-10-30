import Foundation

struct HGS3UploadErrorDetails: Hashable {
    let code: String?
    let message: String?
    let requestID: String?
}

enum HGS3UploadErrorResponse {
    static func details(_ data: Data) -> HGS3UploadErrorDetails? {
        S3ErrorXMLParser.parse(data)
    }

    static func isExpired(_ data: Data) -> Bool {
        let details = details(data)
        let code = details?.code?.lowercased()
        let message = details?.message?.lowercased() ?? ""

        if code == "requestexpired" || code == "expiredtoken" {
            return true
        }

        guard code == "accessdenied" else { return false }
        return ["request has expired", "request expired", "expired token", "token has expired"]
            .contains(where: message.contains)
    }
}

private final class S3ErrorXMLParser: NSObject, XMLParserDelegate {
    private var currentElement: String?
    private var code = ""
    private var message = ""
    private var requestID = ""

    static func parse(_ data: Data) -> HGS3UploadErrorDetails? {
        let delegate = S3ErrorXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return HGS3UploadErrorDetails(
            code: delegate.code.trimmedNilIfEmpty,
            message: delegate.message.trimmedNilIfEmpty,
            requestID: delegate.requestID.trimmedNilIfEmpty
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "Code": code += string
        case "Message": message += string
        case "RequestId": requestID += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        currentElement = nil
    }
}

private extension String {
    var trimmedNilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : String(value.prefix(300))
    }
}
