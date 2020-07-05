Create a restfile for [Rester](https://github.com/finestructure/Rester):

```
swift rester-sitemap.swift https://finestructure.co/sitemap.xml > finestructure.restfile
```

And then run it:

```
rester finestructure.restfile
```

Our use the pre-built docker image:

```
docker run finestructure/rester-sitemap https://finestructure.co/sitemap.xml
```
