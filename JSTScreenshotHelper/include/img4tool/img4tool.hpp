//
//  img4tool.hpp
//  img4tool
//
//  Created by tihmstar on 04.10.19.
//  Copyright © 2019 tihmstar. All rights reserved.
//

#ifndef img4tool_hpp
#define img4tool_hpp

#include <unistd.h>
#include <iostream>
#include <img4tool/ASN1DERElement.hpp>
#include <vector>


#if 1 //HAVE_PLIST
#include <plist/plist.h>
#endif //HAVE_PLIST

namespace tihmstar {
    namespace img4tool {
        const char *version();
        void printIMG4(const void *buf, size_t size, bool printAll, bool im4pOnly);
        void printIM4P(const void *buf, size_t size);
        void printIM4M(const void *buf, size_t size, bool printAll);


        std::string getNameForSequence(const void *buf, size_t size);

        ASN1DERElement getIM4PFromIMG4(const ASN1DERElement &img4);
        ASN1DERElement getIM4MFromIMG4(const ASN1DERElement &img4);
        ASN1DERElement getIM4RFromIMG4(const ASN1DERElement &img4);

        ASN1DERElement getBNCNFromIM4R(const ASN1DERElement &im4r);

        ASN1DERElement getEmptyIMG4Container();
        ASN1DERElement appendIM4PToIMG4(const ASN1DERElement &img4, const ASN1DERElement &im4p);
        ASN1DERElement appendIM4MToIMG4(const ASN1DERElement &img4, const ASN1DERElement &im4m);

        ASN1DERElement getPayloadFromIM4P(const ASN1DERElement &im4p, const char *decryptIv = NULL, const char *decryptKey = NULL, const char **outUsedCompression = NULL, const char **outHypervisor = NULL, size_t *outHypervisorSize = NULL);
        ASN1DERElement getValFromIM4M(const ASN1DERElement &im4m, uint32_t val);

        ASN1DERElement genPrivTagForNumberWithPayload(size_t privnum, const ASN1DERElement &payload);

#if 1 //HAVE_CRYPTO
        ASN1DERElement decryptPayload(const ASN1DERElement &payload, const char *decryptIv, const char *decryptKey);
        std::string getIM4PSHA1(const ASN1DERElement &im4p);
        std::string getIM4PSHA384(const ASN1DERElement &im4p);
        std::string dgstNameForHash(const ASN1DERElement &im4m, std::string hash);
        bool im4mContainsHash(const ASN1DERElement &im4m, std::string hash) noexcept;
        bool isGeneratorValidForIM4M(const ASN1DERElement &im4m, std::string generator) noexcept;
#endif //HAVE_CRYPTO

        ASN1DERElement getEmptyIM4PContainer(const char *type, const char *desc);

        ASN1DERElement appendPayloadToIM4P(const ASN1DERElement &im4p, const void *buf, size_t size, const char *compression = NULL, const void *buf2Raw = NULL, size_t buf2RawSize = 0);

        bool isIMG4(const ASN1DERElement &img4) noexcept;
        bool isIM4P(const ASN1DERElement &im4p) noexcept;
        bool isIM4M(const ASN1DERElement &im4m) noexcept;
        bool isIM4R(const ASN1DERElement &im4m) noexcept;

        ASN1DERElement renameIM4P(const ASN1DERElement &im4p, const char *type);

#if 1 //HAVE_OPENSSL
        bool isIM4MSignatureValid(const ASN1DERElement &im4m);
#endif //HAVE_OPENSSL

#if 1 //HAVE_PLIST
        bool doesIM4MBoardMatchBuildIdentity(const ASN1DERElement &im4m, plist_t buildIdentity) noexcept;
        bool im4mMatchesBuildIdentity(const ASN1DERElement &im4m, plist_t buildIdentity, std::vector<const char*> ignoreWhitelist = {}) noexcept;
        const plist_t getBuildIdentityForIm4m(const ASN1DERElement &im4m, plist_t buildmanifest, std::vector<const char*> ignoreWhitelist = {});
        void printGeneralBuildIdentityInformation(plist_t buildidentity);
        bool isValidIM4M(const ASN1DERElement &im4m, plist_t buildmanifest, std::string forDGSTName = "");
#endif //HAVE_PLIST

    };
};
#endif /* img4tool_hpp */
