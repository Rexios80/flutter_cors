A script to disable and re-enable CORS checks for Flutter's Chrome  & Web Server instances

## Note
This script only disables CORS checks for local testing, and will not help with CORS issues in production. Do not ask for help with production CORS issues as that is outside the scope of this project.

## Use as an executable

### Installation
```console
$ dart pub global activate flutter_cors
```

### Usage
```console
-e, --enable                 Enable CORS checks
-d, --disable                Disable CORS checks
-b, --disable-banner         Disable the warning banner in Chrome
-p, --flutter-path=<path>    Flutter root path (determined automatically if not specified)

$ fluttercors --disable
$ fluttercors --enable
$ fluttercors -db -p /path/to/flutter
```