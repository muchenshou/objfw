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

#include <stdarg.h>

#import "OFArray.h"
#import "OFDataArray.h"
#import "OFString.h"
#import "OFXMLElement.h"
#import "OFAutoreleasePool.h"

#import "OFEnumerationMutationException.h"
#import "OFInvalidArgumentException.h"
#import "OFOutOfRangeException.h"

#import "macros.h"

@implementation OFArray
+ array
{
	return [[[self alloc] init] autorelease];
}

+ arrayWithObject: (id)object
{
	return [[[self alloc] initWithObject: object] autorelease];
}

+ arrayWithObjects: (id)firstObject, ...
{
	id ret;
	va_list arguments;

	va_start(arguments, firstObject);
	ret = [[[self alloc] initWithObject: firstObject
				  arguments: arguments] autorelease];
	va_end(arguments);

	return ret;
}

+ arrayWithArray: (OFArray*)array
{
	return [[[self alloc] initWithArray: array] autorelease];
}

+ arrayWithCArray: (id*)objects
{
	return [[[self alloc] initWithCArray: objects] autorelease];
}

+ arrayWithCArray: (id*)objects
	   length: (size_t)length
{
	return [[[self alloc] initWithCArray: objects
				      length: length] autorelease];
}

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

- initWithObjects: (id)firstObject, ...
{
	id ret;
	va_list arguments;

	va_start(arguments, firstObject);
	ret = [self initWithObject: firstObject
			 arguments: arguments];
	va_end(arguments);

	return ret;
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
	id *cArray;
	size_t i, count;

	self = [self init];

	@try {
		cArray = [array_ cArray];
		count = [array_ count];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	@try {
		for (i = 0; i < count; i++)
			[cArray[i] retain];

		[array addNItems: count
		      fromCArray: cArray];
	} @catch (id e) {
		for (i = 0; i < count; i++)
			[cArray[i] release];

		/* Prevent double-release of objects */
		[array release];
		array = nil;

		[self release];
		@throw e;
	}

	return self;
}

- initWithCArray: (id*)objects
{
	self = [self init];

	@try {
		id *object;
		size_t count = 0;

		for (object = objects; *object != nil; object++) {
			[*object retain];
			count++;
		}

		[array addNItems: count
		      fromCArray: objects];
	} @catch (id e) {
		id *object;

		for (object = objects; *object != nil; object++)
			[*object release];

		[self release];
		@throw e;
	}

	return self;
}

- initWithCArray: (id*)objects
	  length: (size_t)length
{
	self = [self init];

	@try {
		size_t i;

		for (i = 0; i < length; i++)
			[objects[i] retain];

		[array addNItems: length
		      fromCArray: objects];
	} @catch (id e) {
		size_t i;

		for (i = 0; i < length; i++)
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
		OFAutoreleasePool *pool, *pool2;
		OFEnumerator *enumerator;
		OFXMLElement *child;

		pool = [[OFAutoreleasePool alloc] init];

		if (![[element name] isEqual: [self className]] ||
		    ![[element namespace] isEqual: OF_SERIALIZATION_NS])
			@throw [OFInvalidArgumentException newWithClass: isa
							       selector: _cmd];

		enumerator = [[element children] objectEnumerator];
		pool2 = [[OFAutoreleasePool alloc] init];

		while ((child = [enumerator nextObject]) != nil) {
			id object;

			if (![[child namespace] isEqual: OF_SERIALIZATION_NS])
				continue;

			object = [child objectByDeserializing];
			[array addItem: &object];
			[object retain];

			[pool2 releaseObjects];
		}

		[pool release];
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

- (id*)cArray
{
	return [array cArray];
}

- copy
{
	return [self retain];
}

- mutableCopy
{
	return [[OFMutableArray alloc] initWithArray: self];
}

- (id)objectAtIndex: (size_t)index
{
	return *((id*)[array itemAtIndex: index]);
}

- (size_t)indexOfObject: (id)object
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	if (cArray == NULL)
		return OF_INVALID_INDEX;

	for (i = 0; i < count; i++)
		if ([cArray[i] isEqual: object])
			return i;

	return OF_INVALID_INDEX;
}

- (size_t)indexOfObjectIdenticalTo: (id)object
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	if (cArray == NULL)
		return OF_INVALID_INDEX;

	for (i = 0; i < count; i++)
		if (cArray[i] == object)
			return i;

	return OF_INVALID_INDEX;
}

- (BOOL)containsObject: (id)object
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	if (cArray == NULL)
		return NO;

	for (i = 0; i < count; i++)
		if ([cArray[i] isEqual: object])
			return YES;

	return NO;
}

- (BOOL)containsObjectIdenticalTo: (id)object
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	if (cArray == NULL)
		return NO;

	for (i = 0; i < count; i++)
		if (cArray[i] == object)
			return YES;

	return NO;
}

- (id)firstObject
{
	id *firstObject = [array firstItem];

	return (firstObject != NULL ? *firstObject : nil);
}

- (id)lastObject
{
	id *lastObject = [array lastItem];

	return (lastObject != NULL ? *lastObject : nil);
}

- (OFArray*)objectsFromIndex: (size_t)start
		     toIndex: (size_t)end
{
	size_t count = [array count];

	if (end > count || start > end)
		@throw [OFOutOfRangeException newWithClass: isa];

	return [OFArray arrayWithCArray: (id*)[array cArray] + start
				 length: end - start];
}

- (OFArray*)objectsInRange: (of_range_t)range
{
	return [self objectsFromIndex: range.start
			      toIndex: range.start + range.length];
}

- (OFString*)componentsJoinedByString: (OFString*)separator
{
	OFAutoreleasePool *pool;
	OFString *ret;
	OFObject **cArray = [array cArray];
	size_t i, count = [array count];
	IMP append;

	if (count == 0)
		return @"";
	if (count == 1)
		return [cArray[0] description];

	ret = [OFMutableString string];
	append = [ret methodForSelector: @selector(appendString:)];

	pool = [[OFAutoreleasePool alloc] init];

	for (i = 0; i < count - 1; i++) {
		append(ret, @selector(appendString:), [cArray[i] description]);
		append(ret, @selector(appendString:), separator);

		[pool releaseObjects];
	}
	append(ret, @selector(appendString:), [cArray[i] description]);

	[pool release];

	/*
	 * Class swizzle the array to be immutable. We declared the return type
	 * to be OFArray*, so it can't be modified anyway. But not swizzling it
	 * would create a real copy each time -[copy] is called.
	 */
	ret->isa = [OFString class];
	return ret;
}

- (BOOL)isEqual: (id)object
{
	OFArray *otherArray;
	id *cArray, *otherCArray;
	size_t i, count;

	if (![object isKindOfClass: [OFArray class]])
		return NO;

	otherArray = object;

	count = [array count];

	if (count != [otherArray count])
		return NO;

	cArray = [array cArray];
	otherCArray = [otherArray cArray];

	for (i = 0; i < count; i++)
		if (![cArray[i] isEqual: otherCArray[i]])
			return NO;

	return YES;
}

- (uint32_t)hash
{
	id *cArray = [array cArray];
	size_t i, count = [array count];
	uint32_t hash;

	OF_HASH_INIT(hash);

	for (i = 0; i < count; i++) {
		uint32_t h = [cArray[i] hash];

		OF_HASH_ADD(hash, h >> 24);
		OF_HASH_ADD(hash, (h >> 16) & 0xFF);
		OF_HASH_ADD(hash, (h >> 8) & 0xFF);
		OF_HASH_ADD(hash, h & 0xFF);
	}

	OF_HASH_FINALIZE(hash);

	return hash;
}

- (OFString*)description
{
	OFAutoreleasePool *pool;
	OFMutableString *ret;

	if ([array count] == 0)
		return @"()";

	pool = [[OFAutoreleasePool alloc] init];
	ret = [[self componentsJoinedByString: @",\n"] mutableCopy];

	@try {
		[ret prependString: @"(\n"];
		[ret replaceOccurrencesOfString: @"\n"
				     withString: @"\n\t"];
		[ret appendString: @"\n)"];
	} @catch (id e) {
		[ret release];
		@throw e;
	}

	[pool release];

	[ret autorelease];

	/*
	 * Class swizzle the array to be immutable. We declared the return type
	 * to be OFArray*, so it can't be modified anyway. But not swizzling it
	 * would create a real copy each time -[copy] is called.
	 */
	ret->isa = [OFString class];
	return ret;
}

- (OFXMLElement*)XMLElementBySerializing
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	OFAutoreleasePool *pool2;
	OFXMLElement *element;
	id <OFSerialization> *cArray = [array cArray];
	size_t i, count = [array count];

	element = [OFXMLElement elementWithName: [self className]
				      namespace: OF_SERIALIZATION_NS];

	pool2 = [[OFAutoreleasePool alloc] init];

	for (i = 0; i < count; i++) {
		[element addChild: [cArray[i] XMLElementBySerializing]];

		[pool2 releaseObjects];
	}

	[element retain];
	@try {
		[pool release];
	} @finally {
		[element autorelease];
	}

	return element;
}

- (void)makeObjectsPerformSelector: (SEL)selector
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	for (i = 0; i < count; i++)
		((void(*)(id, SEL))[cArray[i]
		    methodForSelector: selector])(cArray[i], selector);
}

- (void)makeObjectsPerformSelector: (SEL)selector
			withObject: (id)object
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	for (i = 0; i < count; i++)
		((void(*)(id, SEL, id))[cArray[i]
		    methodForSelector: selector])(cArray[i], selector, object);
}

- (int)countByEnumeratingWithState: (of_fast_enumeration_state_t*)state
			   objects: (id*)objects
			     count: (int)count_
{
	size_t count = [array count];

	if (count > INT_MAX)
		@throw [OFOutOfRangeException newWithClass: isa];

	if (state->state >= count)
		return 0;

	state->state = count;
	state->itemsPtr = [array cArray];
	state->mutationsPtr = (unsigned long*)self;

	return (int)count;
}

- (OFEnumerator*)objectEnumerator
{
	return [[[OFArrayEnumerator alloc] initWithArray: self
					       dataArray: array
					mutationsPointer: NULL] autorelease];
}

#ifdef OF_HAVE_BLOCKS
- (void)enumerateObjectsUsingBlock: (of_array_enumeration_block_t)block
{
	OFAutoreleasePool *pool = [[OFAutoreleasePool alloc] init];
	id *cArray = [array cArray];
	size_t i, count = [array count];
	BOOL stop = NO;

	for (i = 0; i < count && !stop; i++) {
		block(cArray[i], i, &stop);
		[pool releaseObjects];
	}

	[pool release];
}

- (OFArray*)mappedArrayUsingBlock: (of_array_map_block_t)block
{
	OFArray *ret;
	size_t count = [array count];
	id *tmp = [self allocMemoryForNItems: count
				    withSize: sizeof(id)];

	@try {
		[self enumerateObjectsUsingBlock: ^ (id object, size_t index,
		    BOOL *stop) {
			tmp[index] = block(object, index);
		}];

		ret = [OFArray arrayWithCArray: tmp
					length: count];
	} @finally {
		[self freeMemory: tmp];
	}

	return ret;
}

- (OFArray*)filteredArrayUsingBlock: (of_array_filter_block_t)block
{
	OFArray *ret;
	size_t count = [array count];
	id *tmp = [self allocMemoryForNItems: count
				    withSize: sizeof(id)];

	@try {
		__block size_t i = 0;

		[self enumerateObjectsUsingBlock: ^ (id object, size_t index,
		    BOOL *stop) {
			if (block(object, index))
				tmp[i++] = object;
		}];

		ret = [OFArray arrayWithCArray: tmp
					length: i];
	} @finally {
		[self freeMemory: tmp];
	}

	return ret;
}

- (id)foldUsingBlock: (of_array_fold_block_t)block
{
	size_t count = [array count];
	__block id current;

	if (count == 0)
		return nil;
	if (count == 1)
		return [[[self firstObject] retain] autorelease];

	[self enumerateObjectsUsingBlock: ^ (id object, size_t index,
	    BOOL *stop) {
		id new;

		if (index == 0) {
			current = [object retain];
			return;
		}

		@try {
			new = [block(current, object) retain];
		} @finally {
			[current release];
		}
		current = new;
	}];

	return [current autorelease];
}
#endif

- (void)dealloc
{
	id *cArray = [array cArray];
	size_t i, count = [array count];

	for (i = 0; i < count; i++)
		[cArray[i] release];

	[array release];

	[super dealloc];
}
@end

@implementation OFArrayEnumerator
-    initWithArray: (OFArray*)array_
	 dataArray: (OFDataArray*)dataArray_
  mutationsPointer: (unsigned long*)mutationsPtr_
{
	self = [super init];

	array = [array_ retain];
	dataArray = [dataArray_ retain];
	count = [dataArray count];
	mutations = (mutationsPtr_ != NULL ? *mutationsPtr_ : 0);
	mutationsPtr = mutationsPtr_;

	return self;
}

- (void)dealloc
{
	[array release];
	[dataArray release];

	[super dealloc];
}

- (id)nextObject
{
	if (mutationsPtr != NULL && *mutationsPtr != mutations)
		@throw [OFEnumerationMutationException newWithClass: isa
							     object: array];

	if (pos < count)
		return *(id*)[dataArray itemAtIndex: pos++];

	return nil;
}

- (void)reset
{
	if (mutationsPtr != NULL && *mutationsPtr != mutations)
		@throw [OFEnumerationMutationException newWithClass: isa
							     object: array];

	pos = 0;
}
@end
