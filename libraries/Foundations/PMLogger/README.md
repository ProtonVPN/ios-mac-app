# PMLogger

Log module for both iOS and macOS apps. It is built on top of Apples [SwiftLog library](https://github.com/apple/swift-log).


## Usage

Import PMLogger library and set up variable for logging: 

```
public let log: Logging.Logger = Logging.Logger(label: "ProtonVPN.logger")
```


In AppDelegate setup your log handlers:

```
LoggingSystem.bootstrap {_ in
    return MultiplexLogHandler([
        OSLogHandler(),
        FileLogHandler(self.container.makeLogFileManager().getFileUrl(named: AppConstants.Filenames.appLogFilename))
    ])
}
```


Log:

```
log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])
log.error("Couldn't determine if protocol \"\(vpnProtocol.localizedString)\" is active: \"\(String(describing: error))\"", category: .connection)
```

### Log categories and events

`Logger+Categories.swift` contains all the log categories and evenets used to categorizes logs for easier debugging. More about categories and evenets can be read on Confluence. 


## Main parts

### Handlers

Log handlers receive each logged line and decide what to to with them. Currently there are two log handlers provided: `File` and `OSLog`.
* `FileLogHandler` saves all received logs into the file. It rotates log file when the file reaches `maxFileSize`. `maxArchivedFilesCount` number of archive logs are saved plus the current log file.
* `OSLogHandler` forwards all logs into the systems OSLog.

> More about LogHandlers can be found in [SwiftLog documentation](https://github.com/apple/swift-log).


### Formatters

Formatters let you format resulting log string as required. For example when logging to the system and XCode, we can add colorful emojis to make it easier to parse logs with eyes:
```
🔵 INFO  | USER_CERT | Certificate refresh timer invalidated |
```

It also allows us to not print the datetime information when pushing logs to OSLog, as these already have this information embedded.


### LogContent

`LogContent` classes are used to read the content of logs made by the app or it's parts (like Network Extensions and similar). please read comments in each file regarding each class that implements `LogContent`. 


