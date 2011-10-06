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

#include <alloca.h>
#include <unistd.h>

#include <sys/wait.h>

#import "OFProcess.h"
#import "OFString.h"
#import "OFArray.h"

#import "OFInitializationFailedException.h"
#import "OFReadFailedException.h"
#import "OFWriteFailedException.h"

@implementation OFProcess
+ processWithProgram: (OFString*)program
	 programName: (OFString*)programName
	   arguments: (OFArray*)arguments
{
	return [[[self alloc] initWithProgram: program
				  programName: programName
				    arguments: arguments] autorelease];
}

- initWithProgram: (OFString*)program
      programName: (OFString*)programName
	arguments: (OFArray*)arguments
{
	self = [super init];

	@try {
		if (pipe(readPipe) != 0 || pipe(writePipe) != 0)
			@throw [OFInitializationFailedException
			    exceptionWithClass: isa];

		switch ((pid = fork())) {
		case 0:;
			OFString **cArray = [arguments cArray];
			size_t i, count = [arguments count];
			char **argv = alloca((count + 2) * sizeof(char*));

			argv[0] = (char*)[programName cStringWithEncoding:
			    OF_STRING_ENCODING_NATIVE];

			for (i = 0; i < count; i++)
				argv[i + 1] = (char*)[cArray[i]
				    cStringWithEncoding:
				    OF_STRING_ENCODING_NATIVE];

			argv[i + 1] = NULL;

			close(readPipe[0]);
			close(writePipe[1]);
			dup2(writePipe[0], 0);
			dup2(readPipe[1], 1);
			execvp([program cStringWithEncoding:
			    OF_STRING_ENCODING_NATIVE], argv);

			@throw [OFInitializationFailedException
			    exceptionWithClass: isa];
		case -1:
			@throw [OFInitializationFailedException
			    exceptionWithClass: isa];
		default:
			close(readPipe[1]);
			close(writePipe[0]);
			break;
		}
	} @catch (id e) {
		[self release];
		@throw e;
	}

	return self;
}

- (BOOL)_isAtEndOfStream
{
	if (readPipe[0] == -1)
		return YES;

	return atEndOfStream;
}

- (size_t)_readNBytes: (size_t)length
	   intoBuffer: (void*)buffer
{
	ssize_t ret;

	if (readPipe[0] == -1 || atEndOfStream ||
	    (ret = read(readPipe[0], buffer, length)) < 0)
		@throw [OFReadFailedException exceptionWithClass: isa
							  stream: self
						 requestedLength: length];

	if (ret == 0)
		atEndOfStream = YES;

	return ret;
}

- (void)_writeNBytes: (size_t)length
	  fromBuffer: (const void*)buffer
{
	if (writePipe[1] == -1 || atEndOfStream ||
	    write(writePipe[1], buffer, length) < length)
		@throw [OFWriteFailedException exceptionWithClass: isa
							   stream: self
						  requestedLength: length];
}

- (void)dealloc
{
	[self close];

	[super dealloc];
}

/*
 * FIXME: Add -[fileDescriptor]. The problem is that we have two FDs, which is
 *	  not yet supported by OFStreamObserver. This has to be split into one
 *	  FD for reading and one for writing.
 */

- (void)close
{
	if (readPipe[0] != -1)
		close(readPipe[0]);
	if (writePipe[1] != -1)
		close(writePipe[1]);

	if (pid != -1)
		waitpid(pid, &status, WNOHANG);

	pid = -1;
	readPipe[0] = -1;
	writePipe[1] = -1;
}
@end