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

#import "lua.h"
#import "lualib.h"
#import "lauxlib.h"
