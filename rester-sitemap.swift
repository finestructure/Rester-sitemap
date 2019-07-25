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

protocol Restable {
    var loc: URL { get }
}


struct SiteUrl: Restable {
    let loc: URL
    let changeFreq: String?
    let priority: String?
    let lastMod: String?

    enum Elements: String, CaseIterable {
        case loc
        case changefreq
        case priority
        case lastmod
    }

    init?(_ dictionary: [String: String]) {
        let dictionary = dictionary.mapValues {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard
            let loc = dictionary["loc"],
            let url = URL(string: loc)
            else {
                print("failed to parse url: \(dictionary)")
                return nil
        }
        self.loc = url
        self.changeFreq = dictionary["changefreq"]
        self.priority = dictionary["priority"]
        self.lastMod = dictionary["lastmod"]
    }
}

struct ImageUrl: Restable {
    let loc: URL
    let title: String?

    enum Elements: String, CaseIterable {
        case loc = "image:loc"
        case title = "image:title"
    }

    init?(_ dictionary: [String: String]) {
        let dictionary = dictionary.mapValues {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard
            let loc = dictionary["image:loc"],
            let url = URL(string: loc)
            else {
                print("failed to parse url: \(dictionary)")
                return nil
        }
        self.loc = url
        self.title = dictionary["title"]
    }
}


var results: [Restable] = []

class ParserDelegate: NSObject, XMLParserDelegate {
    var currentElement: String?
    var currentUrl = [String: String]()
    var currentImage = [String: String]()

    func parserDidStartDocument(_ parser: XMLParser) {
        results = []
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        currentElement = elementName
        if currentElement == "url" {
            currentUrl = Dictionary(uniqueKeysWithValues: SiteUrl.Elements.allCases.map { ($0.rawValue, "") })
        }
        if currentElement == "image:image" {
            currentImage = Dictionary(uniqueKeysWithValues: ImageUrl.Elements.allCases.map { ($0.rawValue, "") })
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let e = currentElement else { return }
        currentUrl[e]?.append(string)
        currentImage[e]?.append(string)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "url" {
            guard let siteUrl = SiteUrl(currentUrl) else { return }
            results.append(siteUrl)
            currentUrl = [:]
        }
        if elementName == "image:image" {
            guard let image = ImageUrl(currentImage) else { return }
            results.append(image)
            currentImage = [:]
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
    }

}

let parserDelegate = ParserDelegate()


func printRestfile(urls: [Restable]) {
    print("requests:")
    print("")
    for url in urls {
        print("  path \(url.loc.path):")
        print("    url: \(url.loc)")
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
        printRestfile(urls: results)
    }
    semaphore.signal()
}
task.resume()
semaphore.wait()
