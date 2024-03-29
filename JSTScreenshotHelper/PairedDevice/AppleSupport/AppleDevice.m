//
//  AppleDevice.m
//  JSTColorPicker
//
//  Created by Darwin on 1/17/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import "JSTScreenshotHelperProtocol.h"
#import "AppleDevice.h"
#import "JSTPixelImage.h"
#import <libimobiledevice/libimobiledevice.h>
#import <libimobiledevice/lockdown.h>
#import <libimobiledevice/screenshotr.h>
#import <libimobiledevice/sbservices.h>

#ifdef APP_STORE
#import "JSTColorPickerHelper-Swift.h"
#else
#import "JSTScreenshotHelper-Swift.h"
#endif

@implementation AppleDevice {
    idevice_t cDevice;
    char *cUDID;
}

@synthesize udid = _udid;

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: [%@/%@/%@/%@/%@]>", NSStringFromClass([AppleDevice class]), [self.type uppercaseString], self.name, self.udid, self.model, self.version];
}

- (instancetype)initWithUDID:(NSString *)udid
                        Type:(JSTDeviceType)type
{
    
    NSString *deviceName = @"Unknown Device";
    NSString *deviceModel = @"Unknown Model";
    
    NSString *productVersion = nil;
    
    cDevice = NULL;
    cUDID = strndup(udid.UTF8String, udid.length);
    if (idevice_new_with_options(&cDevice, cUDID, IDEVICE_LOOKUP_USBMUX | IDEVICE_LOOKUP_NETWORK) != IDEVICE_E_SUCCESS) {
        return nil;
    }
    lockdownd_client_t comm;
    if (lockdownd_client_new(cDevice, &comm, "JSTColorPicker") != LOCKDOWN_E_SUCCESS) {
        idevice_free(cDevice); cDevice = nil;
        return nil;
    }
    char *cDeviceName = NULL;
    if (lockdownd_get_device_name(comm, &cDeviceName) == LOCKDOWN_E_SUCCESS) {
        if (cDeviceName) {
            deviceName = [NSString stringWithUTF8String:cDeviceName];
            free(cDeviceName);
        }
    }
    plist_t pProductType = NULL;
    if (lockdownd_get_value(comm, NULL, "ProductType", &pProductType) == LOCKDOWN_E_SUCCESS) {
        if (pProductType && (plist_get_node_type(pProductType) == PLIST_STRING)) {
            char *cProductType = NULL;
            plist_get_string_val(pProductType, &cProductType);
            if (cProductType) {
                deviceModel = [NSString stringWithUTF8String:cProductType];
                free(cProductType);
            }
        }
        if (pProductType) {
            plist_free(pProductType);
        }
    }
    plist_t pProductVersion = NULL;
    if (lockdownd_get_value(comm, NULL, "ProductVersion", &pProductVersion) == LOCKDOWN_E_SUCCESS) {
        if (pProductVersion && (plist_get_node_type(pProductVersion) == PLIST_STRING)) {
            char *cProductVersion = NULL;
            plist_get_string_val(pProductVersion, &cProductVersion);
            if (cProductVersion) {
                productVersion = [NSString stringWithUTF8String:cProductVersion];;
                free(cProductVersion);
            }
        }
        if (pProductVersion) {
            plist_free(pProductVersion);
        }
    }
    lockdownd_goodbye(comm);
    lockdownd_client_free(comm);
    if (self = [super initWithBase:udid
                              Name:deviceName
                             Model:deviceModel
                              Type:type
                           Version:productVersion])
    {
        assert([self hasValidType]);
        
        _udid = udid;
        _productType = deviceModel;
        _productVersion = productVersion;
    }
    return self;
}

- (BOOL)hasValidType {
    return [[self type] isEqualToString:JSTDeviceTypeUSB] || [[self type] isEqualToString:JSTDeviceTypeNetwork];
}

- (void)setType:(JSTDeviceType)type {
    [super setType:type];
    assert([self hasValidType]);
}

- (void)dealloc {
    if (cDevice) { idevice_free(cDevice); cDevice = NULL; }
    if (cUDID) { free(cUDID); cUDID = NULL; }
#ifdef DEBUG
    NSLog(@"- [%@ dealloc]", NSStringFromClass([self class]));
#endif
}

- (void)takeScreenshotWithCompletionHandler:(JSTScreenshotHandler)completion {
    BOOL sbsRequired = NO;

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
        [self pair:completion];
        return;
    }
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(lckd, SBSERVICES_SERVICE_NAME, &sbsService)) || !(sbsService && sbsService->port > 0)) {
        if (sbsRequired && lckd) {
            lockdownd_goodbye(lckd);
            lockdownd_client_free(lckd);
            lckd = NULL;
        }
        if (sbsRequired) {
            [self mount:completion];
            return;
        }
    }
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(lckd, SCREENSHOTR_SERVICE_NAME, &shotrService)) || !(shotrService && shotrService->port > 0)) {
        if (lckd) {
            lockdownd_goodbye(lckd);
            lockdownd_client_free(lckd);
            lckd = NULL;
        }
        [self mount:completion];
        return;
    }

    if (lckd) {
        lockdownd_goodbye(lckd);
        lockdownd_client_free(lckd);
        lckd = NULL;
    }
    
    if (SBSERVICES_E_SUCCESS != (sbret = sbservices_client_new(device, sbsService, &sbs))) {
        if (sbsService) {
            lockdownd_service_descriptor_free(sbsService);
            sbsService = NULL;
        }
        if (sbsRequired && shotrService) {
            lockdownd_service_descriptor_free(shotrService);
            shotrService = NULL;
        }
        if (sbsRequired) {
            completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:sbret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Could not connect to “%@”.", @"kJSTScreenshotError"), @SBSERVICES_SERVICE_NAME] }]);
            return;
        }
    }
    if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_client_new(device, shotrService, &shotr))) {
        if (sbs) {
            sbservices_client_free(sbs);
            sbs = NULL;
        }
        if (sbsService) {
            lockdownd_service_descriptor_free(sbsService);
            sbsService = NULL;
        }
        if (shotrService) {
            lockdownd_service_descriptor_free(shotrService);
            shotrService = NULL;
        }
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedString(@"Could not connect to “%@”.", @"kJSTScreenshotError"), @SCREENSHOTR_SERVICE_NAME] }]);
        return;
    }
    
    sbservices_interface_orientation_t orientation = SBSERVICES_INTERFACE_ORIENTATION_UNKNOWN;
    if (sbs) {
        if (SBSERVICES_E_SUCCESS != (sbret = sbservices_get_interface_orientation(sbs, &orientation)) && orientation != SBSERVICES_INTERFACE_ORIENTATION_UNKNOWN) {
            if (sbs) {
                sbservices_client_free(sbs);
                sbs = NULL;
            }
            if (sbsRequired && shotr) {
                screenshotr_client_free(shotr);
                shotr = NULL;
            }
            if (sbsService) {
                lockdownd_service_descriptor_free(sbsService);
                sbsService = NULL;
            }
            if (sbsRequired && shotrService) {
                lockdownd_service_descriptor_free(shotrService);
                shotrService = NULL;
            }
            if (sbsRequired) {
                completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:sbret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not get the interface orientation.", @"kJSTScreenshotError") }]);
                return;
            }
        }
    }
    
    char *cIMGData = NULL;
    uint64_t cIMGSize = 0;
    if (SCREENSHOTR_E_SUCCESS != (scret = screenshotr_take_screenshot(shotr, &cIMGData, &cIMGSize)) || cIMGData == NULL) {
        if (sbs) {
            sbservices_client_free(sbs);
            sbs = NULL;
        }
        if (shotr) {
            screenshotr_client_free(shotr);
            shotr = NULL;
        }
        if (sbsService) {
            lockdownd_service_descriptor_free(sbsService);
            sbsService = NULL;
        }
        if (shotrService) {
            lockdownd_service_descriptor_free(shotrService);
            shotrService = NULL;
        }
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not get the screenshot.", @"kJSTScreenshotError") }]);
        return;
    }
    
    BOOL isPNGData = NO;
    BOOL isTIFFData = NO;
    if (memcmp(cIMGData, "\x89PNG", MIN(4, cIMGSize)) == 0) { isPNGData = YES; }
    else if (memcmp(cIMGData, "MM\x00*", MIN(4, cIMGSize)) == 0) { isTIFFData = YES; }
    else {
        free(cIMGData);
        if (sbs) {
            sbservices_client_free(sbs);
            sbs = NULL;
        }
        if (shotr) {
            screenshotr_client_free(shotr);
            shotr = NULL;
        }
        if (sbsService) {
            lockdownd_service_descriptor_free(sbsService);
            sbsService = NULL;
        }
        if (shotrService) {
            lockdownd_service_descriptor_free(shotrService);
            shotrService = NULL;
        }
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not get the PNG/TIFF representation of screenshot.", @"kJSTScreenshotError") }]);
        return;
    }
    
    CGImageRef image = nil;
    CFDataRef imageData = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, (const UInt8 *)cIMGData, cIMGSize, kCFAllocatorDefault);
    if (isTIFFData) {
        CFDictionaryRef sourceOpts = (__bridge CFDictionaryRef)@{
            (id)kCGImageSourceShouldCache: (id)kCFBooleanFalse,
            (id)kCGImageSourceTypeIdentifierHint: (id)kUTTypeTIFF,
        };
        CGImageSourceRef imgSrc = CGImageSourceCreateWithData(imageData, sourceOpts);
        CFRelease(imageData);
        image = CGImageSourceCreateImageAtIndex(imgSrc, 0, sourceOpts);
        CFRelease(imgSrc);
    }
    else {
        CGDataProviderRef imageDataProvider = CGDataProviderCreateWithCFData(imageData);
        CFRelease(imageData);
        image = CGImageCreateWithPNGDataProvider(imageDataProvider, NULL, false, kCGRenderingIntentDefault);
        CGDataProviderRelease(imageDataProvider);
    }
    
    if (!image) {
        if (sbs) {
            sbservices_client_free(sbs);
            sbs = NULL;
        }
        if (shotr) {
            screenshotr_client_free(shotr);
            shotr = NULL;
        }
        if (sbsService) {
            lockdownd_service_descriptor_free(sbsService);
            sbsService = NULL;
        }
        if (shotrService) {
            lockdownd_service_descriptor_free(shotrService);
            shotrService = NULL;
        }
        completion(nil, [NSError errorWithDomain:kJSTScreenshotError code:scret userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"Could not create image from the screenshot.", @"kJSTScreenshotError") }]);
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
    
    if (sbs) {
        sbservices_client_free(sbs);
        sbs = NULL;
    }
    if (shotr) {
        screenshotr_client_free(shotr);
        shotr = NULL;
    }
    if (sbsService) {
        lockdownd_service_descriptor_free(sbsService);
        sbsService = NULL;
    }
    if (shotrService) {
        lockdownd_service_descriptor_free(shotrService);
        shotrService = NULL;
    }
}

@end
