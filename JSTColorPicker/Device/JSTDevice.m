//
//  JSTDevice.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTDevice.h"
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <libimobiledevice/screenshotr.h>

@implementation JSTDevice {
    idevice_t cDevice;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<JSTDevice: [%@ %@]>", self.name, self.udid];
}

- (BOOL)isEqual:(id)object {
    return [self.udid isEqual:object];
}

- (NSString *)menuTitle {
    return [NSString stringWithFormat:@"%@ (%@)", self.name, self.udid];
}

- (instancetype)initWithUDID:(NSString *)udid {
    NSString *name = @"Unknown";
    if (idevice_new(&cDevice, udid.UTF8String) != IDEVICE_E_SUCCESS) {
        return nil;
    }
    lockdownd_client_t cClient;
    if (lockdownd_client_new(cDevice, &cClient, "JSTColorPicker") != LOCKDOWN_E_SUCCESS) {
        idevice_free(cDevice);
        return nil;
    }
    char *cDeviceName;
    if (lockdownd_get_device_name(cClient, &cDeviceName) == LOCKDOWN_E_SUCCESS) {
        name = [NSString stringWithUTF8String:cDeviceName];
        free(cDeviceName);
    }
    lockdownd_client_free(cClient);
    if (self = [super init]) {
        _udid = udid;
        _name = name;
    }
    return self;
}

+ (instancetype)deviceWithUDID:(NSString *)udid {
    return [[JSTDevice alloc] initWithUDID:udid];
}

- (void)dealloc {
    idevice_free(cDevice);
#ifdef DEBUG
    NSLog(@"- [%@ dealloc]", NSStringFromClass([self class]));
#endif
}

- (void)screenshotWithCompletionHandler:(JSTScreenshotHandler)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        idevice_t device = self->cDevice;
        lockdownd_client_t lckd = NULL;
        lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;
        screenshotr_client_t shotr = NULL;
        lockdownd_service_descriptor_t service = NULL;
        
        if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new_with_handshake(device, &lckd, NULL))) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(JSTScreenshotTypeUnknown, nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: @"Could not connect to lockdownd." }]);
            });
            return;
        }
        
        screenshotr_error_t scret = SCREENSHOTR_E_UNKNOWN_ERROR;
        ldret = lockdownd_start_service(lckd, "com.apple.mobile.screenshotr", &service);
        lockdownd_client_free(lckd);
        
        if (service && service->port > 0) {
            if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_client_new(device, service, &shotr))) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(JSTScreenshotTypeUnknown, nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: @"Could not connect to screenshotr." }]);
                });
            } else {
                char *cIMGData = NULL;
                uint64_t cIMGSize = 0;
                if (SCREENSHOTR_E_SUCCESS == (scret = screenshotr_take_screenshot(shotr, &cIMGData, &cIMGSize))) {
                    JSTScreenshotType dataType;
                    if (memcmp(cIMGData, "\x89PNG", MIN(4, cIMGSize)) == 0) {
                        // png
                        dataType = JSTScreenshotTypePNG;
                    } else if (memcmp(cIMGData, "MM\x00*", MIN(4, cIMGSize)) == 0) {
                        // tiff
                        dataType = JSTScreenshotTypeTIFF;
                    } else {
                        // unknown
                        dataType = JSTScreenshotTypeUnknown;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(dataType, [NSData dataWithBytes:cIMGData length:cIMGSize], nil);
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(JSTScreenshotTypeUnknown, nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: @"Could not get screenshot." }]);
                    });
                }
                screenshotr_client_free(shotr);
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(JSTScreenshotTypeUnknown, nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: @"Could not start screenshotr service. Remember that you have to mount the Developer Disk Image on your device if you want to use the screenshotr service." }]);
            });
        }

        if (service) {
            lockdownd_service_descriptor_free(service);
        }
        
    });
}

@end
