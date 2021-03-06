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

#import "OFXMLElement.h"
#import "OFXMLElement+Serialization.h"
#import "OFSerialization.h"
#import "OFString.h"

#import "OFInvalidArgumentException.h"
#import "OFNotImplementedException.h"

#import "autorelease.h"
#import "macros.h"

int _OFXMLElement_Serialization_reference;

@implementation OFXMLElement (Serialization)
- (id)objectByDeserializing
{
	void *pool = objc_autoreleasePoolPush();
	Class class;
	id object;

	if ((class = objc_lookUpClass([name cStringWithEncoding:
	    OF_STRING_ENCODING_ASCII])) == Nil)
		@throw [OFNotImplementedException exceptionWithClass: Nil];

	if (![class conformsToProtocol: @protocol(OFSerialization)])
		@throw [OFNotImplementedException
		    exceptionWithClass: class
			      selector: @selector(initWithSerialization:)];

	object = [[class alloc] initWithSerialization: self];

	objc_autoreleasePoolPop(pool);

	return [object autorelease];
}
@end
