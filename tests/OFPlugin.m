/*
 * Copyright (c) 2008 - 2009
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE included in
 * the packaging of this file.
 */

#include "config.h"

#import "OFPlugin.h"
#import "OFAutoreleasePool.h"
#import "OFString.h"
#import "OFExceptions.h"

#import "main.h"

#import "plugin/TestPlugin.h"

static OFString *module = @"OFPlugin";

void
plugin_tests()
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	TestPlugin *plugin;

	TEST(@"+[pluginFromFile:]",
	    (plugin = [OFPlugin pluginFromFile: @"plugin/TestPlugin"]))

	TEST(@"TestPlugin's -[test:]", [plugin test: 1234] == 2468)

	[pool release];
}