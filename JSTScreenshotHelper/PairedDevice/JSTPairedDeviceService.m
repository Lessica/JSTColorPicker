//
//  JSTPairedDeviceService.m
//  JSTScreenshotHelper
//
//  Created by Darwin on 3/23/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTPairedDeviceService.h"
#import "JSTPairedDevice.h"
#import "JSTPairedDeviceStore.h"
#import <Carbon/Carbon.h>


@interface JSTPairedDeviceService () <JSTPairedDeviceDelegate, NSNetServiceBrowserDelegate>
@property (nonatomic, assign) BOOL isNetworkDiscoveryEnabled;
@end


@implementation JSTPairedDeviceService

- (void)setNetworkDiscoveryEnabled:(BOOL)enabled {
    _isNetworkDiscoveryEnabled = enabled;
}

- (void)discoverDevices {
    [self didReceiveiDeviceEvent:self.deviceService];
}

- (void)discoveredDevicesWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    NSMutableArray <NSDictionary *> *discoveredDevices = [[NSMutableArray alloc] initWithCapacity:self.deviceService.activeDevices.count];
    for (JSTPairedDevice *connectedDevice in self.deviceService.activeDevices.allValues) {
        [discoveredDevices addObject:@{
            @"name": connectedDevice.name,
            @"udid": connectedDevice.udid,
            @"type": connectedDevice.type,
            @"model": connectedDevice.model,
        }];
    }
    reply([NSPropertyListSerialization dataWithPropertyList:discoveredDevices
                                                     format:NSPropertyListBinaryFormat_v1_0
                                                    options:0
                                                      error:nil], nil);
}

- (void)lookupDeviceByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    JSTPairedDevice *targetDevice = self.deviceService.cachedDevices[udid];
    if (!targetDevice) {
        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Device \"%@\" is not reachable.", @"kJSTScreenshotError"), udid] }]);
        return;
    }
    reply([NSPropertyListSerialization dataWithPropertyList:@{
        @"name": targetDevice.name,
        @"udid": targetDevice.udid,
        @"type": targetDevice.type,
        @"model": targetDevice.model,
    } format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil], nil);
}

- (void)takeScreenshotByUDID:(NSString *)udid withReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    JSTPairedDevice *targetDevice = self.deviceService.cachedDevices[udid];
    if (!targetDevice) {
        targetDevice = [JSTPairedDevice deviceWithUDID:udid type:JSTDeviceTypeUSB];
    }
    if (!targetDevice) {
        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Device \"%@\" is not reachable.", @"kJSTScreenshotError"), udid] }]);
        return;
    }
    __weak typeof(self) weakSelf = self;
    [targetDevice takeScreenshotWithCompletionHandler:^(NSData * _Nullable imageData, NSError * _Nullable error) {
        reply(imageData, error);
        if (error) {
            [weakSelf disconnectDevice:targetDevice];
            [weakSelf didReceiveiDeviceEvent:self.deviceService];
        }
    }];
}

- (void)disconnectDevice:(JSTPairedDevice *)device {
    [self.deviceService disconnectDevice:device];
}

- (void)disconnectAllDevices {
    [self.deviceService disconnectAllDevices];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _deviceService = [[JSTPairedDeviceStore alloc] init];
        _deviceService.delegate = self;
        [self didReceiveiDeviceEvent:self.deviceService];
    }
    return self;
}

- (void)didReceiveiDeviceEvent:(nonnull JSTPairedDeviceStore *)service {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray <JSTPairedDevice *> *connectedDevices = [service connectedDevicesIncludingNetworkDevices:self.isNetworkDiscoveryEnabled];
        NSLog(@"%@", connectedDevices);
    });
}

- (void)tellConsoleToStartStreamingWithReply:(void (^)(NSData * _Nullable, NSError * _Nullable))reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        // load script
        NSURL *scptURL = [[NSBundle mainBundle] URLForResource:@"open_console" withExtension:@"scpt"];
        if (!scptURL) {
            reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Internal error occurred.", @"kJSTScreenshotError") }]);
            return;
        }

        NSDictionary *errors = nil;
        NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:scptURL error:&errors];
        if (!script) {
            reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"%@ (%@).", @"kJSTScreenshotError"), errors[NSAppleScriptErrorMessage], errors[NSAppleScriptErrorNumber]] }]);
            return;
        }

        // setup parameters
        NSAppleEventDescriptor *message = [NSAppleEventDescriptor descriptorWithString:NSLocalizedString(@"process:JSTColorPicker", @"tellConsoleToStartStreamingWithReply:")];
        NSAppleEventDescriptor *parameters = [NSAppleEventDescriptor listDescriptor];
        [parameters insertDescriptor:message atIndex:1];

        // setup target
        ProcessSerialNumber psn = {0, kCurrentProcess};
        NSAppleEventDescriptor *target = [NSAppleEventDescriptor descriptorWithDescriptorType:typeProcessSerialNumber bytes:&psn length:sizeof(ProcessSerialNumber)];

        // setup event
        NSAppleEventDescriptor *handler = [NSAppleEventDescriptor descriptorWithString:@"open_console"];
        NSAppleEventDescriptor *event = [NSAppleEventDescriptor appleEventWithEventClass:kASAppleScriptSuite eventID:kASSubroutineEvent targetDescriptor:target returnID:kAutoGenerateReturnID transactionID:kAnyTransactionID];
        [event setParamDescriptor:handler forKeyword:keyASSubroutineName];
        [event setParamDescriptor:parameters forKeyword:keyDirectObject];

        // execute
        NSAppleEventDescriptor *result = [script executeAppleEvent:event error:&errors];
        if (![result booleanValue]) {

            // ask for permission #1
            NSDictionary *options = @{(__bridge NSString *)kAXTrustedCheckOptionPrompt: @(YES)};
            BOOL accessibilityEnabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
            if (!accessibilityEnabled) {
                reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"User consent required in \"Preferences > Privacy > Accessibility\".", comment: @"kJSTScreenshotError") }]);
                return;
            }

            // ask for permission #2
            NSArray <NSString *> *askIdentifiers = @[
                @"com.apple.Console",
                @"com.apple.systemevents",
            ];
            for (NSString *askIdentifier in askIdentifiers) {
                NSAppleEventDescriptor *askTarget = [NSAppleEventDescriptor descriptorWithBundleIdentifier:askIdentifier];
                OSStatus askErr = AEDeterminePermissionToAutomateTarget(askTarget.aeDesc, typeWildCard, typeWildCard, true);
                switch (askErr) {
                    case -600:
                        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Not running application with identifier \"%@\".", @"kJSTScreenshotError"), askIdentifier] }]);
                        return;
                    case 0:
                        break;
                    case errAEEventWouldRequireUserConsent:
                        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"User consent required for application with identifier \"%@\" in \"Preferences > Privacy > Automation\".", @"kJSTScreenshotError"), askIdentifier] }]);
                        return;
                    case errAEEventNotPermitted:
                        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"User did not allow usage for application with identifier \"%@\".\nPlease open \"Preferences > Privacy > Automation\" and allow access to \"Console\" and \"System Events\".", @"kJSTScreenshotError"), askIdentifier] }]);
                        return;
                    default:
                        reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:askErr userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Unknown error occurred.", comment: @"kJSTScreenshotError") }]);
                        return;
                }
            }

            reply(nil, [NSError errorWithDomain:kJSTScreenshotError code:404 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"%@ (%@).", @"kJSTScreenshotError"), errors[NSAppleScriptErrorMessage], errors[NSAppleScriptErrorNumber]] }]);
            return;
        }

        reply([NSPropertyListSerialization dataWithPropertyList:@{ @"succeed": @(YES) }
                                                         format:NSPropertyListBinaryFormat_v1_0
                                                        options:0
                                                          error:nil], nil);
    });
}

@end
