# Fetch and download webpage program

## Build image
```
docker build -t fetch_page .
```
Shortcut:
```
make build
```

## Run program
```
docker run -it -v "$(pwd)":/app fetch_page ruby fetch.rb <Arguments>
```
Shortcut:
```
make run <Arguments>
```
Example:
```
make run https://qiita.com
```
```
make run https://qiita.com --metadata
```