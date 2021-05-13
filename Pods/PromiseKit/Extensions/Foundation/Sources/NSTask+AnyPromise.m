#import <Foundation/NSDictionary.h>
#import <Foundation/NSFileHandle.h>
#import <PromiseKit/PromiseKit.h>
#import <Foundation/NSString.h>
#import <Foundation/NSError.h>

#if TARGET_OS_MAC && !TARGET_OS_EMBEDDED && !TARGET_OS_SIMULATOR && !TARGET_OS_UIKITFORMAC

#import "NSTask+AnyPromise.h"

@implementation NSTask (PromiseKit)

- (AnyPromise *)promise {
    return [AnyPromise promiseWithResolverBlock:^(PMKResolver resolve) {
        self.standardOutput = [NSPipe pipe];
        self.standardError = [NSPipe pipe];
        self.terminationHandler = ^(NSTask *task){
            id stdoutData = [[task.standardOutput fileHandleForReading] readDataToEndOfFile];
            id stdoutString = [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding];
            id stderrData = [[task.standardError fileHandleForReading] readDataToEndOfFile];
            id stderrString = [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding];

            if (task.terminationReason == NSTaskTerminationReasonExit && self.terminationStatus == 0) {
                resolve(PMKManifold(stdoutString, stderrString, stdoutData));
            } else {
                id cmd = [NSMutableArray arrayWithObject:task.launchPath];
                [cmd addObjectsFromArray:task.arguments];
                cmd = [cmd componentsJoinedByString:@" "];

                id info = @{
                    NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed executing: %@.", cmd],
                    PMKTaskErrorStandardOutputKey: stdoutString,
                    PMKTaskErrorStandardErrorKey: stderrString,
                    PMKTaskErrorExitStatusKey: @(task.terminationStatus),
                };

                resolve([NSError errorWithDomain:PMKErrorDomain code:PMKTaskError userInfo:info]);
            }
        };

    #if __clang_major__ >= 9
        if (@available(macOS 10.13, *)) {
            NSError *error = nil;
            
            if (![self launchAndReturnError:&error]) {
                resolve(error);
            }
        } else {
            [self launch];
        }
    #else
        [self launch];  // might @throw
    #endif
    }];
}

@end

#endif
