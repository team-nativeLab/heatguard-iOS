import Foundation

enum HGS3UploadErrorResponse {
    static func isExpired(_ data: Data) -> Bool {
        let details = S3ErrorXMLParser.parse(data)
        let code = details.code?.lowercased()
        let message = details.message?.lowercased() ?? ""

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

    static func parse(_ data: Data) -> (code: String?, message: String?) {
        let delegate = S3ErrorXMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return (nil, nil) }
        return (delegate.code.nilIfEmpty, delegate.message.nilIfEmpty)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "Code": code += string
        case "Message": message += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        currentElement = nil
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
