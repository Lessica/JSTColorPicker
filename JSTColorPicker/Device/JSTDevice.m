//
//  JSTDevice.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTDevice.h"
#import "JSTPixelImage.h"
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <libimobiledevice/screenshotr.h>
#import <libimobiledevice/sbservices.h>


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
    if (idevice_new_with_options(&cDevice, udid.UTF8String, IDEVICE_LOOKUP_USBMUX | IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
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
    if (cDevice) {
        idevice_free(cDevice);
    }
#ifdef DEBUG
    NSLog(@"- [%@ dealloc]", NSStringFromClass([self class]));
#endif
}

- (void)screenshotWithCompletionHandler:(JSTScreenshotHandler)completion {
    
    idevice_t device = self->cDevice;
    lockdownd_client_t lckd = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;
    screenshotr_client_t shotr = NULL;
    lockdownd_service_descriptor_t shotrService = NULL;
    sbservices_client_t sbs = NULL;
    lockdownd_service_descriptor_t sbsService = NULL;
    sbservices_error_t sbret = SBSERVICES_E_UNKNOWN_ERROR;
    screenshotr_error_t scret = SCREENSHOTR_E_UNKNOWN_ERROR;
    
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new_with_handshake(device, &lckd, NULL))) {
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: @"Could not connect to lockdownd." }]);
        return;
    }
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(lckd, SBSERVICES_SERVICE_NAME, &sbsService)) || !(sbsService && sbsService->port > 0)) {
        lockdownd_client_free(lckd);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not start \"%@\" service. Remember that you have to mount the Developer Disk Image on your device if you want to use the \"%@\" service.", @SBSERVICES_SERVICE_NAME, @SBSERVICES_SERVICE_NAME] }]);
        return;
    }
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(lckd, SCREENSHOTR_SERVICE_NAME, &shotrService)) || !(shotrService && shotrService->port > 0)) {
        lockdownd_client_free(lckd);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not start \"%@\" service. Remember that you have to mount the Developer Disk Image on your device if you want to use the \"%@\" service.", @SCREENSHOTR_SERVICE_NAME, @SCREENSHOTR_SERVICE_NAME] }]);
        return;
    }
    lockdownd_client_free(lckd);
    
    if (SBSERVICES_E_SUCCESS != (sbret = sbservices_client_new(device, sbsService, &sbs))) {
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:sbret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not connect to \"%@\".", @SBSERVICES_SERVICE_NAME] }]);
        return;
    }
    if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_client_new(device, shotrService, &shotr))) {
        sbservices_client_free(sbs);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Could not connect to \"%@\".", @SCREENSHOTR_SERVICE_NAME] }]);
        return;
    }
    
    sbservices_interface_orientation_t orientation = SBSERVICES_INTERFACE_ORIENTATION_UNKNOWN;
    if (SBSERVICES_E_SUCCESS != (sbret = sbservices_get_interface_orientation(sbs, &orientation)) && orientation != SBSERVICES_INTERFACE_ORIENTATION_UNKNOWN) {
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:sbret userInfo:@{ NSLocalizedDescriptionKey: @"Could not get interface orientation." }]);
        return;
    }
    
    char *cIMGData = NULL;
    uint64_t cIMGSize = 0;
    if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_take_screenshot(shotr, &cIMGData, &cIMGSize)) && cIMGData != NULL) {
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: @"Could not get screenshot." }]);
        return;
    }
    
    BOOL isPNGData = NO;
    if (memcmp(cIMGData, "\x89PNG", MIN(4, cIMGSize)) == 0) { isPNGData = YES; }
    else if (memcmp(cIMGData, "MM\x00*", MIN(4, cIMGSize)) == 0) {}
    else {}
    
    if (!isPNGData) {
        free(cIMGData);
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: @"Could not get PNG representation of screenshot." }]);
        return;
    }
    
    CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)cIMGData, cIMGSize, kCFAllocatorDefault);
    CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(data);
    CGImageRef image = CGImageCreateWithPNGDataProvider(dataProvider, NULL, false, kCGRenderingIntentDefault);
    JSTPixelImage *pixelImage = [[JSTPixelImage alloc] initWithCGImage:image];
    if (orientation == SBSERVICES_INTERFACE_ORIENTATION_PORTRAIT) {
        [pixelImage setOrientation:0];
    }
    else if (orientation == SBSERVICES_INTERFACE_ORIENTATION_LANDSCAPE_RIGHT) {
        [pixelImage setOrientation:1];
    }
    else if (orientation == SBSERVICES_INTERFACE_ORIENTATION_LANDSCAPE_LEFT) {
        [pixelImage setOrientation:2];
    }
    else if (orientation == SBSERVICES_INTERFACE_ORIENTATION_PORTRAIT_UPSIDE_DOWN) {
        [pixelImage setOrientation:3];
    }
    completion([pixelImage pngRepresentation], nil);
    CFRelease(image);
    CFRelease(dataProvider);
    CFRelease(data);
    
    sbservices_client_free(sbs);
    screenshotr_client_free(shotr);
    lockdownd_service_descriptor_free(sbsService);
    lockdownd_service_descriptor_free(shotrService);
    
}

@end
