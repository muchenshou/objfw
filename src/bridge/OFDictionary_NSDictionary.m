/*
 * Copyright (c) 2008, 2009, 2010, 2011, 2012
 *   Jonathan Schleifer <js@webkeks.org>
 *
 * All rights reserved.
 *
 * This file is part of ObjFW. It may be distributed under the terms of the
 * Q Public License 1.0, which can be found in the file LICENSE.QPL included in
 * the packaging of this file.
 *
 * Alternatively, it may be distributed under the terms of the GNU General
 * Public License, either version 2 or 3, which can be found in the file
 * LICENSE.GPLv2 or LICENSE.GPLv3 respectively included in the packaging of this
 * file.
 */

#import <Foundation/NSDictionary.h>

#import "OFDictionary_NSDictionary.h"

#import "NSBridging.h"
#import "OFBridging.h"

#import "OFInitializationFailedException.h"

@implementation OFDictionary_NSDictionary
- initWithNSDictionary: (NSDictionary*)dictionary_
{
	self = [super init];

	@try {
		dictionary = [dictionary_ retain];

		if (dictionary == nil)
			@throw [OFInitializationFailedException
			    exceptionWithClass: isa];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (id)objectForKey: (id)key
{
	id object;

	if ([key conformsToProtocol: @protocol(OFBridging)])
		key = [key NSObject];

	object = [dictionary objectForKey: key];

	if ([object conformsToProtocol: @protocol(NSBridging)])
		return [object OFObject];

	return object;
}

- (size_t)count
{
	return [dictionary count];
}
@end
