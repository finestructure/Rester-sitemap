import PlaygroundSupport
import Foundation

let url = URL(string: "https://finestructure.co/sitemap.xml")!


let semaphore = DispatchSemaphore(value: 0)


func isLoc(_ element: String?) -> Bool {
    return element == "loc" || element == "image:loc"
}


class ParserDelegate: NSObject, XMLParserDelegate {
    var currentElement: String?
    var buffers: [String] = []
    var urls: [URL] = []

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        currentElement = elementName
        if isLoc(currentElement) {
            buffers.append("")
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isLoc(currentElement), var b = buffers.popLast() {
            b.append(string)
            buffers.append(b)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if
            isLoc(currentElement),
            let string = buffers.popLast() {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed) {
                urls.append(url)
            } else {
                print("failed to parse url: \(trimmed)")
            }
        }

    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
    }

}


func printRestfile(urls: [URL]) {
    print("requests:")
    print("")
    for url in urls.sorted(by: { $0.path < $1.path }) {
        print("  path \(url.path):")
        print("    url: \(url)")
        print("    validation:")
        print("      status: 200")
        print("")
    }
}


let task = URLSession.shared.dataTask(with: url) { data, response, error in
    guard let data = data, error == nil else {
        print(error ?? "Unknown error")
        semaphore.signal()
        return
    }

    let parserDelegate = ParserDelegate()
    let parser = XMLParser(data: data)
    parser.delegate = parserDelegate
    if parser.parse() {
        printRestfile(urls: parserDelegate.urls)
    }
    semaphore.signal()
}

task.resume()
semaphore.wait()
