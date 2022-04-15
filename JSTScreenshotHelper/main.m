//
//  main.m
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>
#import <zlib.h>

#import "JSTPairedDeviceService.h"
#import "JSTScreenshotHelperProtocol.h"


#ifdef DEBUG
unsigned char csreq_dat_enc[] = {
  0xfa, 0xde, 0x0c, 0x00, 0x00, 0x00, 0x00, 0xa0, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x06,
  0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x16, 0x63, 0x6f, 0x6d, 0x2e,
  0x6a, 0x73, 0x74, 0x2e, 0x4a, 0x53, 0x54, 0x43, 0x6f, 0x6c, 0x6f, 0x72,
  0x50, 0x69, 0x63, 0x6b, 0x65, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f,
  0x00, 0x00, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a,
  0x73, 0x75, 0x62, 0x6a, 0x65, 0x63, 0x74, 0x2e, 0x43, 0x4e, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x28, 0x41, 0x70, 0x70, 0x6c,
  0x65, 0x20, 0x44, 0x65, 0x76, 0x65, 0x6c, 0x6f, 0x70, 0x6d, 0x65, 0x6e,
  0x74, 0x3a, 0x20, 0x5a, 0x68, 0x65, 0x6e, 0x67, 0x20, 0x57, 0x75, 0x20,
  0x28, 0x32, 0x35, 0x33, 0x44, 0x39, 0x51, 0x52, 0x34, 0x54, 0x50, 0x29,
  0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0a,
  0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x01, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00
};
unsigned int csreq_dat_enc_len = 160;  /* Apple Development */
#else
#if APP_STORE
unsigned char csreq_dat_enc[] = {
  0xfa, 0xde, 0x0c, 0x00, 0x00, 0x00, 0x00, 0xcc, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x00, 0x06,
  0x00, 0x00, 0x00, 0x0f, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06,
  0x01, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06,
  0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x0f,
  0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0a,
  0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x06, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06,
  0x01, 0x0d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0b,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x73, 0x75, 0x62, 0x6a,
  0x65, 0x63, 0x74, 0x2e, 0x4f, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x0a, 0x47, 0x58, 0x5a, 0x32, 0x33, 0x4d, 0x35, 0x54,
  0x50, 0x32, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x16,
  0x63, 0x6f, 0x6d, 0x2e, 0x6a, 0x73, 0x74, 0x2e, 0x4a, 0x53, 0x54, 0x43,
  0x6f, 0x6c, 0x6f, 0x72, 0x50, 0x69, 0x63, 0x6b, 0x65, 0x72, 0x00, 0x00
};
unsigned int csreq_dat_enc_len = 204;  /* Apple Distribution */
#else
unsigned char csreq_dat_enc[] = {
  0xfa, 0xde, 0x0c, 0x00, 0x00, 0x00, 0x00, 0xc4, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x0f,
  0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x16, 0x63, 0x6f, 0x6d, 0x2e,
  0x6a, 0x73, 0x74, 0x2e, 0x4a, 0x53, 0x54, 0x43, 0x6f, 0x6c, 0x6f, 0x72,
  0x50, 0x69, 0x63, 0x6b, 0x65, 0x72, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07,
  0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a,
  0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x01, 0x09, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x06,
  0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x0a,
  0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06, 0x02, 0x06, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00,
  0x00, 0x00, 0x00, 0x0a, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x63, 0x64, 0x06,
  0x01, 0x0d, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0b,
  0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x73, 0x75, 0x62, 0x6a,
  0x65, 0x63, 0x74, 0x2e, 0x4f, 0x55, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
  0x00, 0x00, 0x00, 0x0a, 0x47, 0x58, 0x5a, 0x32, 0x33, 0x4d, 0x35, 0x54,
  0x50, 0x32, 0x00, 0x00
};
unsigned int csreq_dat_enc_len = 196;  /* Developer ID */
#endif
#endif


@interface JSTListenerDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation JSTListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.

    // Begin Authentication Progress
    pid_t clientProcessIdentifier = newConnection.processIdentifier;
#ifdef DEBUG
    NSLog(@"processIdentifier = %d", clientProcessIdentifier);
#endif

    // Create PID Object
    CFNumberRef cfClientProcessIdentifier = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &clientProcessIdentifier);
    if (cfClientProcessIdentifier == NULL) {
        [newConnection invalidate];
        return NO;
    }

    // Create Sec Attributes
    CFDictionaryRef cfSecAttributes = CFDictionaryCreate(kCFAllocatorDefault, (const void **)&kSecGuestAttributePid, (const void **)&cfClientProcessIdentifier, 1, NULL, NULL);
    if (cfSecAttributes == NULL) {
        CFRelease(cfClientProcessIdentifier);
        [newConnection invalidate];
        return NO;
    }

    // Create SecCode Object
    SecCodeRef secGuestCode = NULL;
    OSStatus osStatus = SecCodeCopyGuestWithAttributes(NULL, cfSecAttributes, kSecCSDefaultFlags, &secGuestCode);
    if (osStatus != errSecSuccess) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        [newConnection invalidate];
        return NO;
    }

    // Check Client Path
    CFURLRef cfClientPath = NULL;
    osStatus = SecCodeCopyPath(secGuestCode, kSecCSDefaultFlags, &cfClientPath);
    if (osStatus != errSecSuccess) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        [newConnection invalidate];
        return NO;
    }

    // Copy POSIX Client Path
    CFStringRef cfClientPOSIXPath = CFURLCopyFileSystemPath(cfClientPath, kCFURLPOSIXPathStyle);
    if (cfClientPOSIXPath == NULL) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        CFRelease(cfClientPath);
        [newConnection invalidate];
        return NO;
    }

#ifdef DEBUG
    NSString *clientPOSIXPath = (__bridge NSString *)cfClientPOSIXPath;
    NSLog(@"clientPOSIXPath = %@", clientPOSIXPath);
#endif

    // Create csreq Data Object
    CFDataRef csreqData = CFDataCreate(kCFAllocatorDefault, csreq_dat_enc, csreq_dat_enc_len);
    if (csreqData == NULL) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        CFRelease(cfClientPath);
        CFRelease(cfClientPOSIXPath);
        [newConnection invalidate];
        return NO;
    }

    // Create SecRequirement Object
    SecRequirementRef secRequirement = NULL;
    osStatus = SecRequirementCreateWithData(csreqData, kSecCSDefaultFlags, &secRequirement);
    if (osStatus != errSecSuccess) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        CFRelease(cfClientPath);
        CFRelease(cfClientPOSIXPath);
        CFRelease(csreqData);
        [newConnection invalidate];
        return NO;
    }

#ifdef DEBUG
    CFStringRef secRequirementString = NULL;
    osStatus = SecRequirementCopyString(secRequirement, kSecCSDefaultFlags, &secRequirementString);
    if (osStatus != errSecSuccess) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        CFRelease(cfClientPath);
        CFRelease(cfClientPOSIXPath);
        CFRelease(csreqData);
        CFRelease(secRequirement);
        [newConnection invalidate];
        return NO;
    }
    NSLog(@"SecRequirement = %@", (__bridge NSString *)secRequirementString);
    CFRelease(secRequirementString);
#endif

    // Check Validity
    CFErrorRef secError = NULL;
    osStatus = SecCodeCheckValidityWithErrors(secGuestCode, kSecCSDefaultFlags, secRequirement, &secError);
    if (osStatus != errSecSuccess) {
#ifdef DEBUG
        CFDictionaryRef secErrorDict = CFErrorCopyUserInfo(secError);
        NSLog(@"SecCode = %d, SecError = %@", osStatus, (__bridge NSDictionary *)secErrorDict);
        CFRelease(secErrorDict);
#endif
        CFRelease(secError);
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        CFRelease(cfClientPath);
        CFRelease(cfClientPOSIXPath);
        CFRelease(csreqData);
        CFRelease(secRequirement);
        [newConnection invalidate];
        return NO;
    }

    // Free All Stuffs
    CFRelease(cfClientProcessIdentifier);
    CFRelease(cfSecAttributes);
    CFRelease(secGuestCode);
    CFRelease(cfClientPath);
    CFRelease(cfClientPOSIXPath);
    CFRelease(csreqData);
    CFRelease(secRequirement);
    
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
    
    NSBundle *currentBundle = [NSBundle mainBundle];
    NSString *currentBundleIdentifier = [currentBundle bundleIdentifier];

#if !DEBUG
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *applicationBundlePath = [NSString stringWithFormat:@"/Applications/%@", kJSTColorPickerBundleName];
    NSString *helperBundlePath = GetJSTColorPickerHelperApplicationPath();
    NSString *launchAgentPath = GetJSTColorPickerHelperLaunchAgentPath();
    NSBundle *applicationBundle = [[NSBundle alloc] initWithPath:applicationBundlePath];
    
    if (![[applicationBundle bundleIdentifier] isEqualToString:kJSTColorPickerBundleIdentifier]) {
        [[NSAlert alertWithError:[NSError errorWithDomain:kJSTColorPickerHelperErrorDomain code:404 userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot find main application of JSTColorPicker: %@", @"kJSTScreenshotHelperError"), applicationBundlePath] }]] runModal];

    uninstall:
        if ([fileManager fileExistsAtPath:launchAgentPath]) {
            os_system([NSString stringWithFormat:@"launchctl unload -w '%@'", escape_arg(launchAgentPath)].UTF8String);

            [[NSWorkspace sharedWorkspace] recycleURLs:@[
                [NSURL fileURLWithPath:launchAgentPath],
                [NSURL fileURLWithPath:helperBundlePath],
            ] completionHandler:^(NSDictionary <NSURL *, NSURL *> * _Nonnull newURLs, NSError * _Nullable error) {
                if (error) {
                    [[NSAlert alertWithError:error] runModal];
                    exit(EXIT_FAILURE);
                }
                exit(EXIT_SUCCESS);
            }];

            CFRunLoopRun();
        }
        return EXIT_SUCCESS;
    }

    NSString *currentBundleVersion = [[currentBundle infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey];
    NSString *currentBundlePath = [currentBundle bundlePath];

    if (![currentBundlePath isEqualToString:helperBundlePath]) {

        BOOL shouldReplace = YES;
        if ([fileManager fileExistsAtPath:helperBundlePath]) {

            NSBundle *testBundle = [[NSBundle alloc] initWithPath:helperBundlePath];
            NSString *testBundleIdentifier = [testBundle bundleIdentifier];
            NSString *testBundleVersion = [[testBundle infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey];

            if ([currentBundleIdentifier isEqualToString:testBundleIdentifier] && [currentBundleVersion isEqualToString:testBundleVersion]) {
                shouldReplace = NO;
            }

        }

        if (shouldReplace) {

            NSError *error = nil;
            BOOL succeed = NO;

            if ([fileManager fileExistsAtPath:helperBundlePath]) {
                succeed = [fileManager removeItemAtPath:helperBundlePath error:&error];
                if (!succeed) {
                    [[NSAlert alertWithError:error] runModal];
                    return EXIT_FAILURE;
                }
            }

            NSString *directoryPath = [helperBundlePath stringByDeletingLastPathComponent];
            if (![fileManager fileExistsAtPath:directoryPath]) {
                succeed = [fileManager createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&error];
                if (!succeed) {
                    [[NSAlert alertWithError:error] runModal];
                    return EXIT_FAILURE;
                }
            }

            succeed = [fileManager copyItemAtPath:currentBundlePath toPath:helperBundlePath error:&error];
            if (!succeed) {
                [[NSAlert alertWithError:error] runModal];
                return EXIT_FAILURE;
            }

        }

        sleep(1);

        if ([fileManager fileExistsAtPath:helperBundlePath]) {

            BOOL isInstallOrUninstall = YES;
            NSAlert *alert = [[NSAlert alloc] init];
            if (![fileManager fileExistsAtPath:launchAgentPath]) {
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
                
                BOOL succeed = NO;

                if (isInstallOrUninstall) {
                    // Install

                    NSString *launchAgentSource = [currentBundle pathForResource:@"com.jst.JSTColorPicker.ScreenshotHelper" ofType:@"plist"];
                    NSMutableDictionary *launchAgentDict = [[[NSDictionary alloc] initWithContentsOfFile:launchAgentSource] mutableCopy];
                    assert(launchAgentSource); assert(launchAgentDict);
                    
                    launchAgentDict[@"ProgramArguments"] = @[
                        [helperBundlePath stringByAppendingPathComponent:@"Contents/MacOS/JSTColorPickerHelper"],
                    ];
                    
                    succeed = [launchAgentDict writeToFile:launchAgentPath atomically:YES];
                    if (!succeed) {
                        [[NSAlert alertWithError:[NSError errorWithDomain:kJSTColorPickerHelperErrorDomain code:403 userInfo:@{ NSLocalizedFailureReasonErrorKey: [NSString stringWithFormat:NSLocalizedString(@"Cannot write launch item to: %@", @"kJSTScreenshotHelperError"), launchAgentPath] }]] runModal];
                        return EXIT_FAILURE;
                    }
                    
                    os_system([NSString stringWithFormat:@"launchctl load -w '%@'", escape_arg(launchAgentPath)].UTF8String);
                    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"jstcolorpicker://activate"]];
                    
                } else {
                    // Uninstall
                    goto uninstall;
                }
                
            }
            
        }

        return EXIT_SUCCESS;
    }
#endif

    // Create the delegate for the service.
    JSTListenerDelegate *delegate = [JSTListenerDelegate new];
    
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:currentBundleIdentifier];
    if (!listener) { return EXIT_FAILURE; }
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method will return immediately.
    [listener resume];
    NSApplicationMain(argc, argv);
    
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
