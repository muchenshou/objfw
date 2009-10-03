/*
 * Copyright (c) 2008 - 2009
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of libobjfw. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE included in
 * the packaging of this file.
 */

#include "config.h"

#import "TestPlugin.h"

@implementation TestPlugin
- (int)test: (int)num
{
	return num * 2;
}
@end

id
init_plugin()
{
	return [[[TestPlugin alloc] init] autorelease];
}