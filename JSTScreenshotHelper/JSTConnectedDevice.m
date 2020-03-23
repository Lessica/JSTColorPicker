//
//  JSTConnectedDevice.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTConnectedDevice.h"
#import "JSTPixelImage.h"
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <libimobiledevice/screenshotr.h>
#import <libimobiledevice/sbservices.h>

@implementation JSTConnectedDevice {
    idevice_t cDevice;
    char *cUDID;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<JSTDevice: [%@ %@]>", self.name, self.udid];
}

- (BOOL)isEqual:(id)object {
    return [self.udid isEqual:object];
}

- (instancetype)initWithUDID:(NSString *)udid {
    NSString *name = @"Unknown";
    cDevice = NULL;
    cUDID = strndup(udid.UTF8String, udid.length);
    if (idevice_new_with_options(&cDevice, cUDID, IDEVICE_LOOKUP_USBMUX | IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        return nil;
    }
    lockdownd_client_t cClient;
    if (lockdownd_client_new(cDevice, &cClient, "JSTColorPicker") != LOCKDOWN_E_SUCCESS) {
        idevice_free(cDevice); cDevice = nil;
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
    return [[JSTConnectedDevice alloc] initWithUDID:udid];
}

- (void)dealloc {
    if (cDevice) { idevice_free(cDevice); cDevice = NULL; }
    if (cUDID) { free(cUDID); cUDID = NULL; }
#ifdef DEBUG
    NSLog(@"- [%@ dealloc]", NSStringFromClass([self class]));
#endif
}

- (void)takeScreenshotWithCompletionHandler:(JSTScreenshotHandler)completion {
    
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
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not connect to lockdownd.", @"kJSTScreenshotError") }]);
        return;
    }
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(lckd, SBSERVICES_SERVICE_NAME, &sbsService)) || !(sbsService && sbsService->port > 0)) {
        lockdownd_client_free(lckd);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Could not start \"%@\" service. Remember that you have to install Xcode or mount the Developer Disk Image on your device manually if you want to use the \"%@\" service.", @"kJSTScreenshotError"), @SBSERVICES_SERVICE_NAME, @SBSERVICES_SERVICE_NAME] }]);
        return;
    }
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(lckd, SCREENSHOTR_SERVICE_NAME, &shotrService)) || !(shotrService && shotrService->port > 0)) {
        lockdownd_client_free(lckd);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:ldret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Could not start \"%@\" service. Remember that you have to install Xcode or mount the Developer Disk Image on your device manually if you want to use the \"%@\" service.", @"kJSTScreenshotError"), @SCREENSHOTR_SERVICE_NAME, @SCREENSHOTR_SERVICE_NAME] }]);
        return;
    }
    lockdownd_client_free(lckd);
    
    if (SBSERVICES_E_SUCCESS != (sbret = sbservices_client_new(device, sbsService, &sbs))) {
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:sbret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Could not connect to \"%@\".", @"kJSTScreenshotError"), @SBSERVICES_SERVICE_NAME] }]);
        return;
    }
    if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_client_new(device, shotrService, &shotr))) {
        sbservices_client_free(sbs);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Could not connect to \"%@\".", @"kJSTScreenshotError"), @SCREENSHOTR_SERVICE_NAME] }]);
        return;
    }
    
    sbservices_interface_orientation_t orientation = SBSERVICES_INTERFACE_ORIENTATION_UNKNOWN;
    if (SBSERVICES_E_SUCCESS != (sbret = sbservices_get_interface_orientation(sbs, &orientation)) && orientation != SBSERVICES_INTERFACE_ORIENTATION_UNKNOWN) {
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:sbret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not get interface orientation.", @"kJSTScreenshotError") }]);
        return;
    }
    
    char *cIMGData = NULL;
    uint64_t cIMGSize = 0;
    if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_take_screenshot(shotr, &cIMGData, &cIMGSize)) && cIMGData != NULL) {
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not get screenshot.", @"kJSTScreenshotError") }]);
        return;
    }
    
    BOOL isPNGData = NO;
    BOOL isTIFFData = NO;
    if (memcmp(cIMGData, "\x89PNG", MIN(4, cIMGSize)) == 0) { isPNGData = YES; }
    else if (memcmp(cIMGData, "MM\x00*", MIN(4, cIMGSize)) == 0) { isTIFFData = YES; }
    else {
        free(cIMGData);
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not get PNG/TIFF representation of screenshot.", @"kJSTScreenshotError") }]);
        return;
    }
    
    CGImageRef image = nil;
    if (isTIFFData) {
        NSURL *temporaryDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
        NSURL *temporaryFileURL = [temporaryDirectoryURL URLByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"tiff"]];
        NSData *temporaryData = [NSData dataWithBytesNoCopy:cIMGData length:cIMGSize];
        
        BOOL temporaryWrite = [temporaryData writeToURL:temporaryFileURL atomically:YES];
        if (!temporaryWrite) {
            sbservices_client_free(sbs);
            screenshotr_client_free(shotr);
            lockdownd_service_descriptor_free(sbsService);
            lockdownd_service_descriptor_free(shotrService);
            completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not write TIFF representation of screenshot to temporary storage.", @"kJSTScreenshotError") }]);
            return;
        }
        
        CFURLRef imageURLRef = (__bridge CFURLRef)temporaryFileURL;
        NSDictionary *sourceOptions = @{
            (id)kCGImageSourceShouldCache: (id)kCFBooleanFalse,
            (id)kCGImageSourceTypeIdentifierHint: (id)kUTTypeTIFF
        };
        CFDictionaryRef sourceOptionsRef = (__bridge CFDictionaryRef)sourceOptions;
        CGImageSourceRef imageSource = CGImageSourceCreateWithURL(imageURLRef, sourceOptionsRef);
        if (!imageSource) {
            sbservices_client_free(sbs);
            screenshotr_client_free(shotr);
            lockdownd_service_descriptor_free(sbsService);
            lockdownd_service_descriptor_free(shotrService);
            completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not read TIFF representation of screenshot from temporary storage.", @"kJSTScreenshotError") }]);
            return;
        }
        
        image = CGImageSourceCreateImageAtIndex(imageSource, 0, sourceOptionsRef);
        CFRelease(imageSource);
    }
    else {
        CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)cIMGData, cIMGSize, kCFAllocatorDefault);
        CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData(data);
        image = CGImageCreateWithPNGDataProvider(dataProvider, NULL, false, kCGRenderingIntentDefault);
        CGDataProviderRelease(dataProvider);
        CFRelease(data);
    }
    
    if (!image) {
        sbservices_client_free(sbs);
        screenshotr_client_free(shotr);
        lockdownd_service_descriptor_free(sbsService);
        lockdownd_service_descriptor_free(shotrService);
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not create image from screenshot.", @"kJSTScreenshotError") }]);
        return;
    }
    
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
    if (image) { CGImageRelease(image); }
    
    sbservices_client_free(sbs);
    screenshotr_client_free(shotr);
    lockdownd_service_descriptor_free(sbsService);
    lockdownd_service_descriptor_free(shotrService);
    
}

@end
