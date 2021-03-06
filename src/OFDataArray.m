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

#include <stdio.h>
#include <string.h>
#include <limits.h>

#import "OFDataArray.h"
#import "OFString.h"
#import "OFFile.h"
#import "OFURL.h"
#import "OFHTTPRequest.h"
#import "OFXMLElement.h"

#import "OFHTTPRequestFailedException.h"
#import "OFInvalidArgumentException.h"
#import "OFInvalidFormatException.h"
#import "OFNotImplementedException.h"
#import "OFOutOfMemoryException.h"
#import "OFOutOfRangeException.h"

#import "autorelease.h"
#import "base64.h"
#import "macros.h"

/* References for static linking */
void _references_to_categories_of_OFDataArray(void)
{
	_OFDataArray_Hashing_reference = 1;
}

@implementation OFDataArray
+ (instancetype)dataArray
{
	return [[[self alloc] init] autorelease];
}

+ (instancetype)dataArrayWithItemSize: (size_t)itemSize
{
	return [[[self alloc] initWithItemSize: itemSize] autorelease];
}

+ (instancetype)dataArrayWithContentsOfFile: (OFString*)path
{
	return [[[self alloc] initWithContentsOfFile: path] autorelease];
}

+ (instancetype)dataArrayWithContentsOfURL: (OFURL*)URL
{
	return [[[self alloc] initWithContentsOfURL: URL] autorelease];
}

+ (instancetype)dataArrayWithStringRepresentation: (OFString*)string
{
	return [[[self alloc]
	    initWithStringRepresentation: string] autorelease];
}

+ (instancetype)dataArrayWithBase64EncodedString: (OFString*)string
{
	return [[[self alloc] initWithBase64EncodedString: string] autorelease];
}

- init
{
	self = [super init];

	itemSize = 1;

	return self;
}

- initWithItemSize: (size_t)itemSize_
{
	self = [super init];

	if (itemSize_ == 0) {
		Class c = [self class];
		[self release];
		@throw [OFInvalidArgumentException exceptionWithClass: c
							     selector: _cmd];
	}

	itemSize = itemSize_;

	return self;
}

- initWithContentsOfFile: (OFString*)path
{
	self = [super init];

	@try {
		OFFile *file = [[OFFile alloc] initWithPath: path
						       mode: @"rb"];

		itemSize = 1;

		@try {
			char *buffer = [self allocMemoryWithSize: of_pagesize];

			while (![file isAtEndOfStream]) {
				size_t length;

				length = [file readIntoBuffer: buffer
						       length: of_pagesize];
				[self addItemsFromCArray: buffer
						   count: length];
			}

			[self freeMemory: buffer];
		} @finally {
			[file release];
		}
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithContentsOfURL: (OFURL*)URL
{
	void *pool;
	OFHTTPRequest *request;
	OFHTTPRequestResult *result;
	Class c;

	c = [self class];
	[self release];

	pool = objc_autoreleasePoolPush();

	if ([[URL scheme] isEqual: @"file"]) {
		self = [[c alloc] initWithContentsOfFile: [URL path]];
		objc_autoreleasePoolPop(pool);
		return self;
	}

	request = [OFHTTPRequest requestWithURL: URL];
	result = [request perform];

	if ([result statusCode] != 200)
		@throw [OFHTTPRequestFailedException
		    exceptionWithClass: [request class]
			       request: request
				result: result];

	self = [[result data] retain];
	objc_autoreleasePoolPop(pool);
	return self;
}

- initWithStringRepresentation: (OFString*)string
{
	self = [super init];

	@try {
		const char *cString;
		size_t i;

		itemSize = 1;
		count = [string UTF8StringLength];

		if (count & 1)
			@throw [OFInvalidFormatException
			    exceptionWithClass: [self class]];

		count >>= 1;
		cString = [string UTF8String];
		data = [self allocMemoryWithSize: count];

		for (i = 0; i < count; i++) {
			uint8_t c1 = cString[2 * i];
			uint8_t c2 = cString[2 * i + 1];
			uint8_t byte;

			if (c1 >= '0' && c1 <= '9')
				byte = (c1 - '0') << 4;
			else if (c1 >= 'a' && c1 <= 'f')
				byte = (c1 - 'a' + 10) << 4;
			else if (c1 >= 'A' && c1 <= 'F')
				byte = (c1 - 'A' + 10) << 4;
			else
				@throw [OFInvalidFormatException
				    exceptionWithClass: [self class]];

			if (c2 >= '0' && c2 <= '9')
				byte |= c2 - '0';
			else if (c2 >= 'a' && c2 <= 'f')
				byte |= c2 - 'a' + 10;
			else if (c2 >= 'A' && c2 <= 'F')
				byte |= c2 - 'A' + 10;
			else
				@throw [OFInvalidFormatException
				    exceptionWithClass: [self class]];

			data[i] = byte;
		}
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithBase64EncodedString: (OFString*)string
{
	self = [super init];

	@try {
		itemSize = 1;

		if (!of_base64_decode(self, [string cStringWithEncoding:
		    OF_STRING_ENCODING_ASCII], [string
		    cStringLengthWithEncoding: OF_STRING_ENCODING_ASCII])) {
			Class c = [self class];
			[self release];
			@throw [OFInvalidFormatException exceptionWithClass: c];
		}
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- initWithSerialization: (OFXMLElement*)element
{
	self = [super init];

	itemSize = 1;

	@try {
		void *pool = objc_autoreleasePoolPush();
		OFString *stringValue;

		if (![[element name] isEqual: [self className]] ||
		    ![[element namespace] isEqual: OF_SERIALIZATION_NS])
			@throw [OFInvalidArgumentException
			    exceptionWithClass: [self class]
				      selector: _cmd];

		stringValue = [element stringValue];

		if (!of_base64_decode(self,
		    [stringValue cStringWithEncoding: OF_STRING_ENCODING_ASCII],
		    [stringValue cStringLengthWithEncoding:
		    OF_STRING_ENCODING_ASCII]))
			@throw [OFInvalidFormatException
			    exceptionWithClass: [self class]];

		objc_autoreleasePoolPop(pool);
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (size_t)count
{
	return count;
}

- (size_t)itemSize
{
	return itemSize;
}

- (void*)cArray
{
	return data;
}

- (void*)itemAtIndex: (size_t)index
{
	if (index >= count)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	return data + index * itemSize;
}

- (void*)firstItem
{
	if (data == NULL || count == 0)
		return NULL;

	return data;
}

- (void*)lastItem
{
	if (data == NULL || count == 0)
		return NULL;

	return data + (count - 1) * itemSize;
}

- (void)addItem: (const void*)item
{
	if (SIZE_MAX - count < 1)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	data = [self resizeMemory: data
			     size: itemSize
			    count: count + 1];

	memcpy(data + count * itemSize, item, itemSize);

	count++;
}

- (void)insertItem: (const void*)item
	   atIndex: (size_t)index
{
	[self insertItemsFromCArray: item
			    atIndex: index
			      count: 1];
}

- (void)addItemsFromCArray: (const void*)cArray
		     count: (size_t)nItems
{
	if (nItems > SIZE_MAX - count)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	data = [self resizeMemory: data
			     size: itemSize
			    count: count + nItems];

	memcpy(data + count * itemSize, cArray, nItems * itemSize);
	count += nItems;
}

- (void)insertItemsFromCArray: (const void*)cArray
		      atIndex: (size_t)index
			count: (size_t)nItems
{
	if (nItems > SIZE_MAX - count || index > count)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	data = [self resizeMemory: data
			     size: itemSize
			    count: count + nItems];

	memmove(data + (index + nItems) * itemSize, data + index * itemSize,
	    (count - index) * itemSize);
	memcpy(data + index * itemSize, cArray, nItems * itemSize);

	count += nItems;
}

- (void)removeItemAtIndex: (size_t)index
{
	[self removeItemsInRange: of_range(index, 1)];
}

- (void)removeItemsInRange: (of_range_t)range
{
	if (range.length > SIZE_MAX - range.location ||
	    range.location + range.length > count)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	memmove(data + range.location * itemSize,
	    data + (range.location + range.length) * itemSize,
	    (count - range.location - range.length) * itemSize);

	count -= range.length;
	@try {
		data = [self resizeMemory: data
				     size: itemSize
				    count: count];
	} @catch (OFOutOfMemoryException *e) {
		/* We don't really care, as we only made it smaller */
	}
}

- (void)removeLastItem
{
	if (count == 0)
		return;

	count--;
	@try {
		data = [self resizeMemory: data
				     size: itemSize
				    count: count];
	} @catch (OFOutOfMemoryException *e) {
		/* We don't care, as we only made it smaller */
	}
}

- (void)removeAllItems
{
	[self freeMemory: data];

	data = NULL;
	count = 0;
}

- copy
{
	OFDataArray *copy = [[[self class] alloc] initWithItemSize: itemSize];

	[copy addItemsFromCArray: data
			   count: count];

	return copy;
}

- (BOOL)isEqual: (id)object
{
	OFDataArray *otherDataArray;

	if (![object isKindOfClass: [OFDataArray class]])
		return NO;

	otherDataArray = object;

	if ([otherDataArray count] != count ||
	    [otherDataArray itemSize] != itemSize)
		return NO;
	if (memcmp([otherDataArray cArray], data, count * itemSize))
		return NO;

	return YES;
}

- (of_comparison_result_t)compare: (id <OFComparing>)object
{
	OFDataArray *otherDataArray;
	int comparison;
	size_t otherCount, minimumCount;

	if (![object isKindOfClass: [OFDataArray class]])
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];
	otherDataArray = (OFDataArray*)object;

	if ([otherDataArray itemSize] != itemSize)
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	otherCount = [otherDataArray count];
	minimumCount = (count > otherCount ? otherCount : count);

	if ((comparison = memcmp(data, [otherDataArray cArray],
	    minimumCount * itemSize)) == 0) {
		if (count > otherCount)
			return OF_ORDERED_DESCENDING;
		if (count < otherCount)
			return OF_ORDERED_ASCENDING;
		return OF_ORDERED_SAME;
	}

	if (comparison > 0)
		return OF_ORDERED_DESCENDING;
	else
		return OF_ORDERED_ASCENDING;
}

- (uint32_t)hash
{
	uint32_t hash;
	size_t i;

	OF_HASH_INIT(hash);
	for (i = 0; i < count * itemSize; i++)
		OF_HASH_ADD(hash, ((char*)data)[i]);
	OF_HASH_FINALIZE(hash);

	return hash;
}

- (OFString*)description
{
	OFMutableString *ret = [OFMutableString stringWithString: @"<"];
	size_t i;

	for (i = 0; i < count; i++) {
		size_t j;

		if (i > 0)
			[ret appendString: @" "];

		for (j = 0; j < itemSize; j++)
			[ret appendFormat: @"%02x", data[i * itemSize + j]];
	}

	[ret appendString: @">"];

	[ret makeImmutable];
	return ret;
}

- (OFString*)stringRepresentation
{
	OFMutableString *ret = [OFMutableString string];
	size_t i, j;

	for (i = 0; i < count; i++)
		for (j = 0; j < itemSize; j++)
			[ret appendFormat: @"%02x", data[i * itemSize + j]];

	[ret makeImmutable];
	return ret;
}

- (OFString*)stringByBase64Encoding
{
	return of_base64_encode(data, count * itemSize);
}

- (void)writeToFile: (OFString*)path
{
	OFFile *file = [[OFFile alloc] initWithPath: path
					       mode: @"wb"];

	@try {
		[file writeBuffer: data
			   length: count * itemSize];
	} @finally {
		[file release];
	}
}

- (OFXMLElement*)XMLElementBySerializing
{
	void *pool;
	OFXMLElement *element;

	if (itemSize != 1)
		@throw [OFNotImplementedException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	pool = objc_autoreleasePoolPush();
	element = [OFXMLElement
	    elementWithName: [self className]
		  namespace: OF_SERIALIZATION_NS
		stringValue: of_base64_encode(data, count * itemSize)];

	[element retain];

	objc_autoreleasePoolPop(pool);

	return [element autorelease];
}
@end

@implementation OFBigDataArray
- (void)addItem: (const void*)item
{
	size_t newSize, lastPageByte;

	if (SIZE_MAX - count < 1 || count + 1 > SIZE_MAX / itemSize)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	lastPageByte = of_pagesize - 1;
	newSize = ((count + 1) * itemSize + lastPageByte) & ~lastPageByte;

	if (size != newSize)
		data = [self resizeMemory: data
				     size: newSize];

	memcpy(data + count * itemSize, item, itemSize);

	count++;
	size = newSize;
}

- (void)addItemsFromCArray: (const void*)cArray
		     count: (size_t)nItems
{
	size_t newSize, lastPageByte;

	if (nItems > SIZE_MAX - count || count + nItems > SIZE_MAX / itemSize)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	lastPageByte = of_pagesize - 1;
	newSize = ((count + nItems) * itemSize + lastPageByte) & ~lastPageByte;

	if (size != newSize)
		data = [self resizeMemory: data
				     size: newSize];

	memcpy(data + count * itemSize, cArray, nItems * itemSize);

	count += nItems;
	size = newSize;
}

- (void)insertItemsFromCArray: (const void*)cArray
		      atIndex: (size_t)index
			count: (size_t)nItems
{
	size_t newSize, lastPageByte;

	if (nItems > SIZE_MAX - count || index > count ||
	    count + nItems > SIZE_MAX / itemSize)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	lastPageByte = of_pagesize - 1;
	newSize = ((count + nItems) * itemSize + lastPageByte) & ~lastPageByte;

	if (size != newSize)
		data = [self resizeMemory: data
				     size: newSize];

	memmove(data + (index + nItems) * itemSize, data + index * itemSize,
	    (count - index) * itemSize);
	memcpy(data + index * itemSize, cArray, nItems * itemSize);

	count += nItems;
	size = newSize;
}

- (void)removeItemsInRange: (of_range_t)range
{
	size_t newSize, lastPageByte;

	if (range.length > SIZE_MAX - range.location ||
	    range.location + range.length > count)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	memmove(data + range.location * itemSize,
	    data + (range.location + range.length) * itemSize,
	    (count - range.location - range.length) * itemSize);

	count -= range.length;
	lastPageByte = of_pagesize - 1;
	newSize = (count * itemSize + lastPageByte) & ~lastPageByte;

	if (size != newSize)
		data = [self resizeMemory: data
				     size: newSize];
	size = newSize;
}

- (void)removeLastItem
{
	size_t newSize, lastPageByte;

	if (count == 0)
		return;

	count--;
	lastPageByte = of_pagesize - 1;
	newSize = (count * itemSize + lastPageByte) & ~lastPageByte;

	if (size != newSize) {
		@try {
			data = [self resizeMemory: data
					     size: newSize];
		} @catch (OFOutOfMemoryException *e) {
			/* We don't care, as we only made it smaller */
		}

		size = newSize;
	}
}

- (void)removeAllItems
{
	[self freeMemory: data];

	data = NULL;
	count = 0;
	size = 0;
}
@end
