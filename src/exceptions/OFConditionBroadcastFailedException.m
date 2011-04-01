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

#import "OFConditionBroadcastFailedException.h"
#import "OFString.h"

#import "OFNotImplementedException.h"

@implementation OFConditionBroadcastFailedException
+ newWithClass: (Class)class_
     condition: (OFCondition*)condition
{
	return [[self alloc] initWithClass: class_
				 condition: condition];
}

- initWithClass: (Class)class_
{
	Class c = isa;
	[self release];
	@throw [OFNotImplementedException newWithClass: c
					      selector: _cmd];
}

- initWithClass: (Class)class_
      condition: (OFCondition*)condition_
{
	self = [super initWithClass: class_];

	@try {
		condition = [condition_ retain];
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (void)dealloc
{
	[condition release];

	[super dealloc];
}

- (OFString*)description
{
	if (description != nil)
		return description;

	description = [[OFString alloc] initWithFormat:
	    @"Broadcasting a condition of type %@ failed!", inClass];

	return description;
}

- (OFCondition*)condition
{
	return condition;
}
@end