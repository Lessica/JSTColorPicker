//
//  main.m
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "JSTScreenshotHelper.h"
#import "JSTConnectedDeviceStore.h"
#ifdef SANDBOXED
#import "JSTLoginItem.h"
#endif


@interface ServiceDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation ServiceDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    
    // Configure the connection.
    // First, set the interface that the exported object implements.
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(JSTScreenshotHelperProtocol)];
    
    // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
    JSTScreenshotHelper *exportedObject = [[JSTScreenshotHelper alloc] init];
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

#ifdef SANDBOXED
int main(int argc, const char *argv[])
{
    
    NSString *applicationBundleIdentifier = kJSTColorPickerBundleIdentifier;
    NSString *applicationBundlePath = [NSString stringWithFormat:@"/Applications/%@", kJSTColorPickerBundleName];
    NSBundle *applicationBundle = [[NSBundle alloc] initWithPath:applicationBundlePath];

    if (![[applicationBundle bundleIdentifier] isEqualToString:applicationBundleIdentifier]) {
        NSLog(@"application not found");
        return EXIT_FAILURE;
    }


    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundleIdentifier = [mainBundle bundleIdentifier];
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

            NSLog(@"copy \"%@\" to \"%@\"", bundlePath, targetPath);

            NSError *error = nil;
            BOOL succeed = NO;

            if ([fileManager fileExistsAtPath:targetPath]) {
                succeed = [fileManager removeItemAtPath:targetPath error:&error];
                if (!succeed) {
                    NSLog(@"error occurred: %@", error);
                    return EXIT_FAILURE;
                }
            }

            NSString *directoryPath = [targetPath stringByDeletingLastPathComponent];
            if (![fileManager fileExistsAtPath:directoryPath]) {
                succeed = [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error];
                if (!succeed) {
                    NSLog(@"error occurred: %@", error);
                    return EXIT_FAILURE;
                }
            }

            succeed = [fileManager copyItemAtPath:bundlePath toPath:targetPath error:&error];
            if (!succeed) {
                NSLog(@"error occurred: %@", error);
                return EXIT_FAILURE;
            }

        }

        sleep(1);

        if ([fileManager fileExistsAtPath:targetPath]) {

            NSURL *targetURL = [NSURL fileURLWithPath:targetPath];
            [JSTLoginItem setLaunchAtLogin:targetURL enabled:YES];
            NSLog(@"set start at login \"%@\"", targetPath);

            if (@available(macOS 10.15, *)) {
                NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration configuration];
                [[NSWorkspace sharedWorkspace] openApplicationAtURL:targetURL configuration:configuration completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
                    if (!app) {
                        NSLog(@"launch failed: %@", error);
                        exit(EXIT_FAILURE);
                    }
                    NSLog(@"launch succeed: %@", app);
                    exit(EXIT_SUCCESS);
                }];

                [[NSRunLoop currentRunLoop] run];
                return EXIT_SUCCESS;
            } else {
                NSError *launchError = nil;
                NSRunningApplication *app = [[NSWorkspace sharedWorkspace] launchApplicationAtURL:targetURL options:(NSWorkspaceLaunchAndHide | NSWorkspaceLaunchWithoutAddingToRecents) configuration:@{} error:&launchError];
                if (!app) {
                    NSLog(@"launch failed: %@", launchError);
                    return EXIT_FAILURE;
                }
                NSLog(@"launch succeed: %@", app);
                return EXIT_SUCCESS;
            }

        }

        return EXIT_SUCCESS;
    }
    
    // Create the delegate for the service.
    ServiceDelegate *delegate = [ServiceDelegate new];
    
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:bundleIdentifier];
    if (!listener) { return EXIT_FAILURE; }
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    [[NSRunLoop currentRunLoop] run];
    return EXIT_SUCCESS;
}
#else
int main(int argc, const char *argv[])
{
    
    // Create the delegate for the service.
    ServiceDelegate *delegate = [ServiceDelegate new];
    
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [NSXPCListener serviceListener];
    if (!listener) { return EXIT_FAILURE; }
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    [[NSRunLoop currentRunLoop] run];
    return EXIT_SUCCESS;
    
}
#endif
