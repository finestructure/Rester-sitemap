FROM swift:5.2.4-bionic

COPY rester-sitemap.swift .
ENTRYPOINT [ "swift", "rester-sitemap.swift" ]
