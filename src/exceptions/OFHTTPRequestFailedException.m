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

#import "OFHTTPRequestFailedException.h"
#import "OFString.h"
#import "OFHTTPRequest.h"

#import "OFNotImplementedException.h"

#import "autorelease.h"
#import "common.h"

@implementation OFHTTPRequestFailedException
+ (instancetype)exceptionWithClass: (Class)class_
			   request: (OFHTTPRequest*)request
			    result: (OFHTTPRequestResult*)result
{
	return [[[self alloc] initWithClass: class_
				    request: request
				     result: result] autorelease];
}

- initWithClass: (Class)class_
{
	Class c = [self class];
	[self release];
	@throw [OFNotImplementedException exceptionWithClass: c
						    selector: _cmd];
}

- initWithClass: (Class)class_
	request: (OFHTTPRequest*)request_
	 result: (OFHTTPRequestResult*)result_
{
	self = [super initWithClass: class_];

	request = [request_ retain];
	result = [result_ retain];

	return self;
}

- (void)dealloc
{
	[request release];
	[result release];

	[super dealloc];
}

- (OFString*)description
{
	void *pool;
	const char *type = "(unknown)";

	if (description != nil)
		return description;

	switch ([request requestType]) {
	case OF_HTTP_REQUEST_TYPE_GET:
		type = "GET";
		break;
	case OF_HTTP_REQUEST_TYPE_HEAD:
		type = "HEAD";
		break;
	case OF_HTTP_REQUEST_TYPE_POST:
		type = "POST";
		break;
	}

	pool = objc_autoreleasePoolPush();

	description = [[OFString alloc] initWithFormat:
	    @"A HTTP %s request in class %@ with URL %@ failed with code %d",
	    type, inClass, [request URL], [result statusCode]];

	objc_autoreleasePoolPop(pool);

	return description;
}

- (OFHTTPRequest*)request
{
	OF_GETTER(request, NO)
}

- (OFHTTPRequestResult*)result
{
	OF_GETTER(result, NO)
}
@end
