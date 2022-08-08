# Timer

Classes for running code at a predefined time in the future. Can be used in both iOS/macOS apps as well as in Network Extensions where there is no defined UI thread. Under the hood `DispatchSource.makeTimerSource` is used.

## Testing

Also includes `BackgroundTimerMock` class for usage in unit tests.
