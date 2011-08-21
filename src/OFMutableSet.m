/*
 * Copyright (c) 2008, 2009, 2010, 2011
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

#include "config.h"

#define OF_MUTABLE_SET_M

#import "OFMutableSet.h"
#import "OFMutableDictionary_hashtable.h"
#import "OFArray.h"
#import "OFNumber.h"
#import "OFAutoreleasePool.h"

@implementation OFMutableSet
- (void)addObject: (id)object
{
	[dictionary _setObject: [OFNumber numberWithSize: 1]
			forKey: object
		       copyKey: NO];

	mutations++;
}

- (void)removeObject: (id)object
{
	[dictionary removeObjectForKey: object];

	mutations++;
}

- (void)minusSet: (OFSet*)set
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFEnumerator *enumerator = [set objectEnumerator];
	id object;

	while ((object = [enumerator nextObject]) != nil)
		[self removeObject: object];

	[pool release];
}

- (void)intersectSet: (OFSet*)set
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFArray *objects = [dictionary allKeys];
	id *cArray = [objects cArray];
	size_t count = [objects count];
	size_t i;

	for (i = 0; i < count; i++)
		if (![set containsObject: cArray[i]])
			[dictionary removeObjectForKey: cArray[i]];

	[pool release];
}

- (void)unionSet: (OFSet*)set
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFEnumerator *enumerator = [set objectEnumerator];
	id object;

	while ((object = [enumerator nextObject]) != nil)
		[self addObject: object];

	[pool release];
}

- (void)makeImmutable
{
	isa = [OFSet class];
}
@end
