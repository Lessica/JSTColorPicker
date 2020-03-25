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
    newConnection.invalidationHandler = ^{
        [exportedObject disconnectAllDevices];
    };
    
    // Resuming the connection allows the system to deliver more incoming messages.
    [newConnection resume];
    
    // Returning YES from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call -invalidate on the connection and return NO.
    return YES;
}

@end

int main(int argc, const char *argv[])
{
    // Create the delegate for the service.
    ServiceDelegate *delegate = [ServiceDelegate new];
    
#ifdef SANDBOXED
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSXPCListener *listener = [[NSXPCListener alloc] initWithMachServiceName:bundleIdentifier];
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    return NSApplicationMain(argc, argv);
#else
    // Set up the one NSXPCListener for this service. It will handle all incoming connections.
    NSXPCListener *listener = [NSXPCListener serviceListener];
    listener.delegate = delegate;
    
    // Resuming the serviceListener starts this service. This method does not return.
    [listener resume];
    
    CFRunLoopRun();
    return 0;
#endif
}
