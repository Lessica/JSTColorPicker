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


unsigned char csreq_dat[] = {
  0x26, 0x85, 0xb4, 0x61, 0x00, 0x03, 0x95, 0x8e, 0xb1, 0x0a, 0xc2, 0x30,
  0x14, 0x45, 0x7f, 0xe5, 0xd1, 0x49, 0x3b, 0xbc, 0x36, 0x89, 0x2d, 0x3a,
  0x38, 0x39, 0x08, 0x82, 0x58, 0xb0, 0x82, 0x28, 0x1d, 0x62, 0xfa, 0xaa,
  0xa9, 0x35, 0x29, 0x69, 0x04, 0x3f, 0xdf, 0xd6, 0x49, 0x1c, 0x44, 0xd7,
  0xcb, 0x3d, 0xe7, 0x5e, 0x69, 0xd4, 0xc5, 0x3a, 0x90, 0x6d, 0xdb, 0x10,
  0x9c, 0xc9, 0x90, 0xd3, 0x0a, 0xa4, 0x29, 0x41, 0x97, 0x64, 0xbc, 0xae,
  0x34, 0x39, 0x08, 0x94, 0xbd, 0x61, 0xdd, 0x79, 0x5c, 0x6d, 0xf3, 0x85,
  0x6d, 0xac, 0xcb, 0xb4, 0xba, 0x92, 0x0b, 0x5e, 0xbd, 0x91, 0x22, 0x37,
  0xf4, 0x94, 0xf4, 0x04, 0x0d, 0xc9, 0xea, 0xd8, 0x33, 0x4d, 0x89, 0x0c,
  0x39, 0x4e, 0x27, 0x31, 0x32, 0x26, 0x52, 0x91, 0x20, 0x8b, 0x63, 0x4c,
  0xfb, 0x70, 0x56, 0x40, 0x14, 0x02, 0x3d, 0x74, 0xe7, 0x3b, 0x08, 0x23,
  0xe8, 0xb7, 0xdf, 0x05, 0xec, 0x1b, 0xcd, 0x31, 0xfd, 0xa0, 0x87, 0x03,
  0xff, 0xed, 0x33, 0xf1, 0x8b, 0xa2, 0xbb, 0x9f, 0x6a, 0x52, 0x1e, 0x37,
  0xbb, 0x02, 0xe6, 0xb0, 0xdc, 0x1f, 0xb8, 0x58, 0x27, 0x79, 0xc6, 0xc7,
  0x4f, 0x70, 0x3b, 0x90, 0xfa, 0x2f, 0x01, 0x00, 0x00
};
unsigned int csreq_dat_len = 177;


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

    NSString *clientPOSIXPath = (__bridge NSString *)cfClientPOSIXPath;
#ifdef DEBUG
    NSLog(@"clientPOSIXPath = %@", clientPOSIXPath);
#endif

    // Fetch Compressed csreq
    int gzMagic = 0x088b1f;
    NSMutableData *gzData = [NSMutableData dataWithBytes:&gzMagic length:4];
    [gzData appendBytes:csreq_dat length:csreq_dat_len];

    // Decompress csreq
    z_stream gzStream;
    gzStream.zalloc = Z_NULL;
    gzStream.zfree = Z_NULL;
    gzStream.avail_in = (uint)gzData.length;
    gzStream.next_in = (Bytef *)gzData.bytes;
    gzStream.total_out = 0;
    gzStream.avail_out = 0;

    NSMutableData *gzOutput = nil;
    if (inflateInit2(&gzStream, 47) == Z_OK)
    {
        int status = Z_OK;
        gzOutput = [NSMutableData dataWithCapacity:gzData.length * 2];
        while (status == Z_OK)
        {
            if (gzStream.total_out >= gzOutput.length)
            {
                gzOutput.length += gzData.length / 2;
            }
            gzStream.next_out = (uint8_t *)gzOutput.mutableBytes + gzStream.total_out;
            gzStream.avail_out = (uInt)(gzOutput.length - gzStream.total_out);
            status = inflate (&gzStream, Z_SYNC_FLUSH);
        }
        if (inflateEnd(&gzStream) == Z_OK)
        {
            if (status == Z_STREAM_END)
            {
                gzOutput.length = gzStream.total_out;
            }
        }
    }

    // Create SecRequirement Object
    SecRequirementRef secRequirement = NULL;
    osStatus =  ((__bridge CFDataRef _Nonnull)(gzOutput), kSecCSDefaultFlags, &secRequirement);
    if (osStatus != errSecSuccess) {
        CFRelease(cfClientProcessIdentifier);
        CFRelease(cfSecAttributes);
        CFRelease(secGuestCode);
        CFRelease(cfClientPath);
        CFRelease(cfClientPOSIXPath);
        [newConnection invalidate];
        return NO;
    }

#ifdef DEBUG
    NSLog(@"SecRequirement = %@", secRequirement);
#endif

    CFRelease(cfClientProcessIdentifier);
    CFRelease(cfSecAttributes);
    CFRelease(secGuestCode);
    CFRelease(cfClientPath);
    CFRelease(cfClientPOSIXPath);
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

            NSString *helperBundlePath = GetJSTColorPickerHelperApplicationPath();
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
                    
                    [[NSWorkspace sharedWorkspace] recycleURLs:@[
                        [NSURL fileURLWithPath:launchAgentTarget],
                        [NSURL fileURLWithPath:helperBundlePath],
                    ] completionHandler:^(NSDictionary<NSURL *,NSURL *> * _Nonnull newURLs, NSError * _Nullable error) {
                        if (error) {
                            [[NSAlert alertWithError:error] runModal];
                            exit(EXIT_FAILURE);
                        }
                        exit(EXIT_SUCCESS);
                    }];
                    
                    CFRunLoopRun();
                    return EXIT_SUCCESS;
                    
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
