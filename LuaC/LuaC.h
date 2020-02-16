//
//  LuaC.h
//  LuaC
//
//  Created by Darwin on 2/16/20.
//  Copyright © 2020 JST. All rights reserved.
//

#import <Foundation/Foundation.h>

extern int SDegutisLuaRegistryIndex;

//! Project version number for LuaC.
FOUNDATION_EXPORT double LuaCVersionNumber;

//! Project version string for LuaC.
FOUNDATION_EXPORT const unsigned char LuaCVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <LuaC/PublicHeader.h>

#import "lapi.h"
#import "lauxlib.h"
#import "lcode.h"
#import "lctype.h"
#import "ldebug.h"
#import "ldo.h"
#import "lfunc.h"
#import "lgc.h"
#import "llex.h"
#import "llimits.h"
#import "lmem.h"
#import "lobject.h"
#import "lopcodes.h"
#import "lparser.h"
#import "lprefix.h"
#import "lstate.h"
#import "lstring.h"
#import "ltable.h"
#import "ltm.h"
#import "lua.h"
#import "luaconf.h"
#import "lualib.h"
#import "lundump.h"
#import "lvm.h"
#import "lzio.h"
