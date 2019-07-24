import Foundation
import PlaygroundSupport
//PlaygroundPage.current.needsIndefiniteExecution = true

let semaphore = DispatchSemaphore(value: 0)


let url = URL(string: "https://finestructure.co/sitemap.xml")!

protocol Restable {
    var loc: URL { get }
}

struct SiteUrl: Restable {
    let loc: URL
    let changeFreq: String?
    let priority: String?
    let lastMod: String?
}

struct ImageUrl: Restable {
    let loc: URL
    let title: String?
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
            currentUrl = ["loc": "", "changefreq": "", "priority": "", "lastmod": ""]
        }
        if currentElement == "image:image" {
            currentImage = ["image:loc": "", "image:title": ""]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let currentElement = currentElement else { return }
        if currentUrl.keys.contains(currentElement) {
            currentUrl[currentElement]! += string
        }
        if currentImage.keys.contains(currentElement) {
            currentImage[currentElement]! += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "url" {
            currentUrl = currentUrl.mapValues {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard
                let loc = currentUrl["loc"],
                let locUrl = URL(string: loc)
                else {
                    print("failed to parse url: \(currentUrl)")
                    return
            }
            let changeFreq = currentUrl["changefreq"]
            let priority = currentUrl["priority"]
            let lastMod = currentUrl["lastmod"]

            let siteUrl = SiteUrl(loc: locUrl, changeFreq: changeFreq, priority: priority, lastMod: lastMod)
            results.append(siteUrl)
            currentUrl = [:]
        }
        if elementName == "image:image" {
            currentImage = currentImage.mapValues {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard
                let loc = currentImage["image:loc"],
                let locUrl = URL(string: loc)
                else {
                    print("failed to parse image: \(currentImage)")
                    return
            }
            let title = currentUrl["title"]

            let image = ImageUrl(loc: locUrl, title: title)
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
