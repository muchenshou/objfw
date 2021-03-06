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

#include <stdarg.h>

#import "OFArray_adjacent.h"
#import "OFMutableArray_adjacent.h"
#import "OFArray_adjacentSubarray.h"
#import "OFDataArray.h"
#import "OFString.h"
#import "OFXMLElement.h"

#import "OFEnumerationMutationException.h"
#import "OFInvalidArgumentException.h"
#import "OFOutOfRangeException.h"

#import "autorelease.h"
#import "macros.h"

@implementation OFArray_adjacent
- init
{
	self = [super init];

	@try {
		array = [[OFDataArray alloc] initWithItemSize: sizeof(id)];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithObject: (id)object
{
	self = [self init];

	@try {
		[array addItem: &object];
		[object retain];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithObject: (id)firstObject
       arguments: (va_list)arguments
{
	self = [self init];

	@try {
		id object;

		[array addItem: &firstObject];
		[firstObject retain];

		while ((object = va_arg(arguments, id)) != nil) {
			[array addItem: &object];
			[object retain];
		}
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithArray: (OFArray*)array_
{
	id *objects;
	size_t i, count;

	self = [self init];

	@try {
		objects = [array_ objects];
		count = [array_ count];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	@try {
		for (i = 0; i < count; i++)
			[objects[i] retain];

		[array addItemsFromCArray: objects
				    count: count];
	} @catch (id e) {
		for (i = 0; i < count; i++)
			[objects[i] release];

		/* Prevent double-release of objects */
		[array release];
		array = nil;

		[self release];
		@throw e;
	}

	return self;
}

- initWithObjects: (id const*)objects
	    count: (size_t)count
{
	self = [self init];

	@try {
		size_t i;

		for (i = 0; i < count; i++)
			[objects[i] retain];

		[array addItemsFromCArray: objects
				    count: count];
	} @catch (id e) {
		size_t i;

		for (i = 0; i < count; i++)
			[objects[i] release];

		[self release];
		@throw e;
	}

	return self;
}

- initWithSerialization: (OFXMLElement*)element
{
	self = [self init];

	@try {
		void *pool = objc_autoreleasePoolPush();
		OFEnumerator *enumerator;
		OFXMLElement *child;

		if ((![[element name] isEqual: @"OFArray"] &&
		    ![[element name] isEqual: @"OFMutableArray"]) ||
		    ![[element namespace] isEqual: OF_SERIALIZATION_NS])
			@throw [OFInvalidArgumentException
			    exceptionWithClass: [self class]
				      selector: _cmd];

		enumerator = [[element elementsForNamespace:
		    OF_SERIALIZATION_NS] objectEnumerator];

		while ((child = [enumerator nextObject]) != nil) {
			void *pool2 = objc_autoreleasePoolPush();
			id object;

			object = [child objectByDeserializing];
			[array addItem: &object];
			[object retain];

			objc_autoreleasePoolPop(pool2);
		}

		objc_autoreleasePoolPop(pool);
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (size_t)count
{
	return [array count];
}

- (id*)objects
{
	return [array cArray];
}

- (id)objectAtIndex: (size_t)index
{
	return *((id*)[array itemAtIndex: index]);
}

- (id)objectAtIndexedSubscript: (size_t)index
{
	return *((id*)[array itemAtIndex: index]);
}

- (void)getObjects: (id*)buffer
	   inRange: (of_range_t)range
{
	id *objects = [array cArray];
	size_t i, count = [array count];

	if (range.length > SIZE_MAX - range.location ||
	    range.location + range.length > count)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	for (i = 0; i < range.length; i++)
		buffer[i] = objects[range.location + i];
}

- (size_t)indexOfObject: (id)object
{
	id *objects = [array cArray];
	size_t i, count = [array count];

	for (i = 0; i < count; i++)
		if ([objects[i] isEqual: object])
			return i;

	return OF_NOT_FOUND;
}

- (size_t)indexOfObjectIdenticalTo: (id)object
{
	id *objects = [array cArray];
	size_t i, count = [array count];

	for (i = 0; i < count; i++)
		if (objects[i] == object)
			return i;

	return OF_NOT_FOUND;
}


- (OFArray*)objectsInRange: (of_range_t)range
{
	if (range.length > SIZE_MAX - range.location ||
	    range.location + range.length > [array count])
		@throw [OFOutOfRangeException
		    exceptionWithClass: [self class]];

	if ([self isKindOfClass: [OFMutableArray class]])
		return [OFArray
		    arrayWithObjects: (id*)[array cArray] + range.location
			       count: range.length];

	return [OFArray_adjacentSubarray arrayWithArray: self
						  range: range];
}

- (BOOL)isEqual: (id)object
{
	OFArray *otherArray;
	id *objects, *otherObjects;
	size_t i, count;

	if ([object class] != [OFArray_adjacent class] &&
	    [object class] != [OFMutableArray_adjacent class] &&
	    [object class] != [OFArray_adjacentSubarray class])
		return [super isEqual: object];

	otherArray = object;

	count = [array count];

	if (count != [otherArray count])
		return NO;

	objects = [array cArray];
	otherObjects = [otherArray objects];

	for (i = 0; i < count; i++)
		if (![objects[i] isEqual: otherObjects[i]])
			return NO;

	return YES;
}

- (uint32_t)hash
{
	id *objects = [array cArray];
	size_t i, count = [array count];
	uint32_t hash;

	OF_HASH_INIT(hash);

	for (i = 0; i < count; i++) {
		uint32_t h = [objects[i] hash];

		OF_HASH_ADD(hash, h >> 24);
		OF_HASH_ADD(hash, (h >> 16) & 0xFF);
		OF_HASH_ADD(hash, (h >> 8) & 0xFF);
		OF_HASH_ADD(hash, h & 0xFF);
	}

	OF_HASH_FINALIZE(hash);

	return hash;
}

#ifdef OF_HAVE_BLOCKS
- (void)enumerateObjectsUsingBlock: (of_array_enumeration_block_t)block
{
	id *objects = [array cArray];
	size_t i, count = [array count];
	BOOL stop = NO;

	for (i = 0; i < count && !stop; i++)
		block(objects[i], i, &stop);
}
#endif

- (void)dealloc
{
	id *objects = [array cArray];
	size_t i, count = [array count];

	for (i = 0; i < count; i++)
		[objects[i] release];

	[array release];

	[super dealloc];
}
@end
