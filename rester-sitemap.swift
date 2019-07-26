import Foundation


extension Collection {
  subscript (safe index: Index) -> Iterator.Element? {
    return indices.contains(index) ? self[index] : nil
  }
}


let args = CommandLine.arguments


guard let urlString = args[safe: 1] else {
    print("Usage: \(args[0]) <sitemap url>")
    print("Example: \(args[0]) https://finestructure.co/sitemap.xml")
    exit(1)
}

guard let url = URL(string: urlString) else {
    print("URL '\(urlString)' is invalid.")
    exit(1)
}


// end of script specific code


let semaphore = DispatchSemaphore(value: 0)


struct TestItem {
    let url: URL

    init?(_ string: String) {
        let string = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: string) else {
            print("failed to parse url: \(string)")
            return nil
        }
        self.url = url
    }
}


func isLoc(_ element: String?) -> Bool {
    return element == "loc" || element == "image:loc"
}


class ParserDelegate: NSObject, XMLParserDelegate {
    var currentElement: String?
    var buffers: [String] = []
    var results: [TestItem] = []

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
            let b = buffers.popLast(),
            let item = TestItem(b) {
            results.append(item)
        }

    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
    }

}


let parserDelegate = ParserDelegate()


func printRestfile(items: [TestItem]) {
    print("requests:")
    print("")
    for i in items.sorted(by: { $0.url.path < $1.url.path }) {
        print("  path \(i.url.path):")
        print("    url: \(i.url)")
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

    let parser = XMLParser(data: data)
    parser.delegate = parserDelegate
    if parser.parse() {
        printRestfile(items: parserDelegate.results)
    }
    semaphore.signal()
}
task.resume()
semaphore.wait()
