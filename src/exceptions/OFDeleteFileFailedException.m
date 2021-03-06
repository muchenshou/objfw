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

#import "OFDeleteFileFailedException.h"
#import "OFString.h"

#import "OFNotImplementedException.h"

#import "common.h"

@implementation OFDeleteFileFailedException
+ (instancetype)exceptionWithClass: (Class)class_
			      path: (OFString*)path_
{
	return [[[self alloc] initWithClass: class_
				       path: path_] autorelease];
}

- initWithClass: (Class)class_
{
	Class c = [self class];
	[self release];
	@throw [OFNotImplementedException exceptionWithClass: c
						    selector: _cmd];
}

- initWithClass: (Class)class_
	   path: (OFString*)path_
{
	self = [super initWithClass: class_];

	@try {
		path  = [path_ copy];
		errNo = GET_ERRNO;
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[path release];

	[super dealloc];
}

- (OFString*)description
{
	if (description != nil)
		return description;

	description = [[OFString alloc] initWithFormat:
	    @"Failed to delete file %@ in class %@! " ERRFMT, path, inClass,
	    ERRPARAM];

	return description;
}

- (int)errNo
{
	return errNo;
}

- (OFString*)path
{
	OF_GETTER(path, NO)
}
@end
