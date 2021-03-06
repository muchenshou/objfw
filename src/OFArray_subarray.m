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

#include "config.h"

#import "OFArray_subarray.h"

#import "OFOutOfRangeException.h"

@implementation OFArray_subarray
+ (instancetype)arrayWithArray: (OFArray*)array
			 range: (of_range_t)range
{
	return [[[self alloc] initWithArray: array
				      range: range] autorelease];
}

- initWithArray: (OFArray*)array_
	  range: (of_range_t)range_
{
	self = [super init];

	@try {
		/* Should usually be retain, as it's useless with a copy */
		array = [array_ copy];
		range = range_;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[array release];

	[super dealloc];
}

- (size_t)count
{
	return range.length;
}

- (id)objectAtIndex: (size_t)index
{
	if (index >= range.length)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	return [array objectAtIndex: index + range.location];
}

- (void)getObjects: (id*)buffer
	   inRange: (of_range_t)range_
{
	if (range_.length > SIZE_MAX - range_.location ||
	    range_.location + range_.length > range.length)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	range_.location += range.location;

	return [array getObjects: buffer
			 inRange: range_];
}

- (size_t)indexOfObject: (id)object
{
	size_t index = [array indexOfObject: object];

	if (index < range.location)
		return OF_NOT_FOUND;

	index -= range.location;

	if (index >= range.length)
		return OF_NOT_FOUND;

	return index;
}

- (size_t)indexOfObjectIdenticalTo: (id)object
{
	size_t index = [array indexOfObjectIdenticalTo: object];

	if (index < range.location)
		return OF_NOT_FOUND;

	index -= range.location;

	if (index >= range.length)
		return OF_NOT_FOUND;

	return index;
}

- (OFArray*)objectsInRange: (of_range_t)range_
{
	if (range_.length > SIZE_MAX - range_.location ||
	    range_.location + range_.length > range.length)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	range_.location += range.location;

	return [array objectsInRange: range_];
}
@end
