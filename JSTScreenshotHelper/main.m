//
//  main.m
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "JSTPairedDeviceService.h"


@interface JSTListenerDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation JSTListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    
    // Configure the connection.
    // First, set the interface that the exported object implements.
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(JSTScreenshotHelperProtocol)];
    
    // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
    JSTPairedDeviceService *exportedObject = [[JSTPairedDeviceService alloc] init];
    newConnection.exportedObject = exportedObject;
    newConnection.interruptionHandler = ^{
        [exportedObject disconnectAllDevices];
    };
    newConnection.invalidationHandler = ^{
        [exportedObject disconnectAllDevices];
    };
    
    // Resuming the connection allows the system to deliver more incoming messages.
    [newConnection resume];
    
    // Returning YES from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call -invalidate on the connection and return NO.
    return YES;
}

@end


#pragma mark - Helper Function

#if APP_STORE

#import <spawn.h>
extern char **environ;

#if !DEBUG
NS_INLINE int os_system(const char *ctx) {
    const char *args[] = {
        "/bin/bash",
        "-c",
        ctx,
        NULL
    };
    
    pid_t pid;
    int posix_status = posix_spawn(&pid, "/bin/bash", NULL, NULL, (char **)args, environ);
    if (posix_status != 0) {
        errno = posix_status; // perror("posix_spawn");
        return -101;
    } else {
        pid_t w; int status;
        do {
            w = waitpid(pid, &status, WUNTRACED | WCONTINUED);
            if (w == -1) {
                // perror("waitpid");
                return -102;
            }
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
        if (WIFEXITED(status)) {
            return 0     + WEXITSTATUS(status);
        } else if (WIFSIGNALED(status)) {
            return -200  - WTERMSIG(status);
        } else if (WIFSTOPPED(status)) {
            return -300  - WSTOPSIG(status);
        } else if (WIFCONTINUED(status)) {
            return 0;
        }
        return -1;
    }
}
#endif

#if !DEBUG
NS_INLINE NSString *escape_arg(NSString *arg) {
    return [arg stringByReplacingOccurrencesOfString:@"\'" withString:@"'\\\''"];
}
#endif


#pragma mark - Main Function

int main(int argc, const char *argv[])
{
    
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = [mainBundle bundleIdentifier];

#if !DEBUG
    NSString *applicationBundleIdentifier = kJSTColorPickerBundleIdentifier;
    NSString *applicationBundlePath = [NSString stringWithFormat:@"/Applications/%@", kJSTColorPickerBundleName];
    NSBundle *applicationBundle = [[NSBundle alloc] initWithPath:applicationBundlePath];
    
    if (![[applicationBundle bundleIdentifier] isEqualToString:applicationBundleIdentifier]) {
        [[NSAlert alertWithError:[NSError errorWithDomain:kJSTColorPickerHelperErrorDomain code:404 userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot find main application of JSTColorPicker: %@", @"kJSTScreenshotHelperError"), applicationBundlePath] }]] runModal];
        return EXIT_FAILURE;
    }

    NSString *bundleVersion = [[mainBundle infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey];
    NSString *bundlePath = [mainBundle bundlePath];
    NSString *targetPath = [[NSString stringWithFormat:@"~/Library/Application Support/JSTColorPicker/%@", kJSTColorPickerHelperBundleName] stringByExpandingTildeInPath];

    if (![bundlePath isEqualToString:targetPath]) {

        NSFileManager *fileManager = [NSFileManager defaultManager];

        BOOL shouldReplace = YES;
        if ([fileManager fileExistsAtPath:targetPath]) {

            NSBundle *testBundle = [[NSBundle alloc] initWithPath:targetPath];
            NSString *testBundleIdentifier = [testBundle bundleIdentifier];
            NSString *testBundleVersion = [[testBundle infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey];

            if ([bundleIdentifier isEqualToString:testBundleIdentifier] && [bundleVersion isEqualToString:testBundleVersion]) {
                shouldReplace = NO;
            }

        }

        if (shouldReplace) {

            NSError *error = nil;
            BOOL succeed = NO;

            if ([fileManager fileExistsAtPath:targetPath]) {
                succeed = [fileManager removeItemAtPath:targetPath error:&error];
                if (!succeed) {
                    [[NSAlert alertWithError:error] runModal];
                    return EXIT_FAILURE;
                }
            }

            NSString *directoryPath = [targetPath stringByDeletingLastPathComponent];
            if (![fileManager fileExistsAtPath:directoryPath]) {
                succeed = [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error];
                if (!succeed) {
                    [[NSAlert alertWithError:error] runModal];
                    return EXIT_FAILURE;
                }
            }

            succeed = [fileManager copyItemAtPath:bundlePath toPath:targetPath error:&error];
            if (!succeed) {
                [[NSAlert alertWithError:error] runModal];
                return EXIT_FAILURE;
            }

        }

        sleep(1);

        if ([fileManager fileExistsAtPath:targetPath]) {
            
            NSString *launchAgentTarget = GetJSTColorPickerHelperLaunchAgentPath();
            
            BOOL isInstallOrUninstall = YES;
            NSAlert *alert = [[NSAlert alloc] init];
            if (![fileManager fileExistsAtPath:launchAgentTarget]) {
                [alert setMessageText:NSLocalizedString(@"Do you want to setup JSTColorPickerHelper as a login item?", @"JSTScreenshotHelperInstall")];
                isInstallOrUninstall = YES;
            } else {
                [alert setMessageText:NSLocalizedString(@"Do you want to remove JSTColorPickerHelper from login items?", @"JSTScreenshotHelperInstall")];
                isInstallOrUninstall = NO;
            }
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
            [alert setAlertStyle:NSAlertStyleWarning];
            
            NSModalResponse alertResp = [alert runModal];
            if (alertResp == NSAlertFirstButtonReturn) {
                
                NSError *error = nil;
                BOOL succeed = NO;

                if (isInstallOrUninstall) {
                    
                    NSString *launchAgentSource = [mainBundle pathForResource:@"com.jst.JSTColorPicker.ScreenshotHelper" ofType:@"plist"];
                    NSMutableDictionary *launchAgentDict = [[[NSDictionary alloc] initWithContentsOfFile:launchAgentSource] mutableCopy];
                    assert(launchAgentSource); assert(launchAgentDict);
                    
                    launchAgentDict[@"ProgramArguments"] = @[
                        [targetPath stringByAppendingPathComponent:@"Contents/MacOS/JSTColorPickerHelper"],
                    ];
                    
                    succeed = [launchAgentDict writeToFile:launchAgentTarget atomically:YES];
                    if (!succeed) {
                        [[NSAlert alertWithError:[NSError errorWithDomain:kJSTColorPickerHelperErrorDomain code:403 userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot write launch item to: %@", @"kJSTScreenshotHelperError"), launchAgentTarget] }]] runModal];
                        return EXIT_FAILURE;
                    }
                    
                    os_system([NSString stringWithFormat:@"launchctl load -w '%@'", escape_arg(launchAgentTarget)].UTF8String);
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"jstcolorpicker://activate"]];
                    
                } else {
                    
                    os_system([NSString stringWithFormat:@"launchctl unload -w '%@'", escape_arg(launchAgentTarget)].UTF8String);
                    
                    succeed = [fileManager removeItemAtPath:launchAgentTarget error:&error];
                    if (!succeed) {
                        [[NSAlert alertWithError:error] runModal];
                        return EXIT_FAILURE;
                    }
                    
                }
                
            }
            
        }

        return EXIT_SUCCESS;
    }
#endif

    // Create the delegate for the service.
    JSTListenerDelegate *delegate = [JSTListenerDelegate new];
    
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:bundleIdentifier];
    if (!listener) { return EXIT_FAILURE; }
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    return EXIT_SUCCESS;
    
}
#else
int main(int argc, const char *argv[])
{
    
    // Create the delegate for the service.
    JSTListenerDelegate *delegate = [JSTListenerDelegate new];
    
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [NSXPCListener serviceListener];
    if (!listener) { return EXIT_FAILURE; }
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    return EXIT_SUCCESS;
    
}
#endif
