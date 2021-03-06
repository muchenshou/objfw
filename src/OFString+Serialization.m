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

#import "OFString.h"
#import "OFString+Serialization.h"
#import "OFSerialization.h"
#import "OFArray.h"
#import "OFXMLElement.h"
#import "OFXMLAttribute.h"

#import "OFInvalidArgumentException.h"
#import "OFMalformedXMLException.h"
#import "OFUnboundNamespaceException.h"
#import "OFUnsupportedVersionException.h"

#import "autorelease.h"

int _OFString_Serialization_reference;

@implementation OFString (Serialization)
- (id)objectByDeserializing
{
	void *pool = objc_autoreleasePoolPush();
	OFXMLElement *root;
	OFString *version;
	OFArray *elements;
	id object;

	@try {
		root = [OFXMLElement elementWithXMLString: self];
	} @catch (OFMalformedXMLException *e) {
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];
	} @catch (OFUnboundNamespaceException *e) {
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];
	}

	version = [[root attributeForName: @"version"] stringValue];
	if (version == nil)
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	if ([version decimalValue] != 1)
		@throw [OFUnsupportedVersionException
		    exceptionWithClass: [self class]
			       version: version];

	elements = [root elementsForNamespace: OF_SERIALIZATION_NS];

	if ([elements count] != 1)
		@throw [OFInvalidArgumentException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	object = [[[elements firstObject] objectByDeserializing] retain];

	objc_autoreleasePoolPop(pool);

	return [object autorelease];
}
@end
