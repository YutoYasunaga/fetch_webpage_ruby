# Fetch and download webpage program

## Build image
```
docker build -t fetch_page .
```

## Run program
```
docker run -it -v "$(pwd)":/app fetch_page ruby fetch.rb <Arguments>
```

## Example:
### Fetch and download
```
docker run -it -v "$(pwd)":/app fetch_page ruby fetch.rb https://qiita.com
```

### Fetch metadata only
```
docker run -it -v "$(pwd)":/app fetch_page ruby fetch.rb https://qiita.com --metadata
```