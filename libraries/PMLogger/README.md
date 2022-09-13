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

