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

#ifndef __STDC_LIMIT_MACROS
# define __STDC_LIMIT_MACROS
#endif
#ifndef __STDC_CONSTANT_MACROS
# define __STDC_CONSTANT_MACROS
#endif

#include <sys/types.h>

#import "OFStream.h"

#ifdef _WIN32
# include <windows.h>
#endif

/*!
 * @brief A class for stream-like communication with a newly created process.
 */
@interface OFProcess: OFStream
{
#ifndef _WIN32
	pid_t pid;
	int readPipe[2], writePipe[2];
#else
	HANDLE readPipe[2], writePipe[2];
#endif
	int status;
	BOOL atEndOfStream;
}

/*!
 * @brief Creates a new OFProcess with the specified program and invokes the
 *	  program.
 *
 * @param program The program to execute. If it does not start with a slash, the
 *		  search path specified in PATH is used.
 * @return A new, autoreleased OFProcess.
 */
+ (instancetype)processWithProgram: (OFString*)program;

/*!
 * @brief Creates a new OFProcess with the specified program and arguments and
 *	  invokes the program.
 *
 * @param program The program to execute. If it does not start with a slash, the
 *		  search path specified in PATH is used.
 * @param arguments The arguments to pass to the program, or nil
 * @return A new, autoreleased OFProcess.
 */
+ (instancetype)processWithProgram: (OFString*)program
			 arguments: (OFArray*)arguments;

/*!
 * @brief Creates a new OFProcess with the specified program, program name and
 *	  arguments and invokes the program.
 *
 * @param program The program to execute. If it does not start with a slash, the
 *		  search path specified in PATH is used.
 * @param programName The program name for the program to invoke (argv[0]).
 *		      Usually, this is equal to program.
 * @param arguments The arguments to pass to the program, or nil
 * @return A new, autoreleased OFProcess.
 */
+ (instancetype)processWithProgram: (OFString*)program
		       programName: (OFString*)programName
			 arguments: (OFArray*)arguments;

/*!
 * @brief Initializes an already allocated OFProcess with the specified program
 *	  and invokes the program.
 *
 * @param program The program to execute. If it does not start with a slash, the
 *		  search path specified in PATH is used.
 * @return An initialized OFProcess.
 */
- initWithProgram: (OFString*)program;

/*!
 * @brief Initializes an already allocated OFProcess with the specified program
 *	  and arguments and invokes the program.
 *
 * @param program The program to execute. If it does not start with a slash, the
 *		  search path specified in PATH is used.
 * @param arguments The arguments to pass to the program, or nil
 * @return An initialized OFProcess.
 */
- initWithProgram: (OFString*)program
	arguments: (OFArray*)arguments;

/*!
 * @brief Initializes an already allocated OFProcess with the specified program,
 *	  program name and arguments and invokes the program.
 *
 * @param program The program to execute. If it does not start with a slash, the
 *		  search path specified in PATH is used.
 * @param programName The program name for the program to invoke (argv[0]).
 *		      Usually, this is equal to program.
 * @param arguments The arguments to pass to the program, or nil
 * @return An initialized OFProcess.
 */
- initWithProgram: (OFString*)program
      programName: (OFString*)programName
	arguments: (OFArray*)arguments;

/*!
 * @brief Closes the write direction of the process.
 *
 * This method needs to be called for some programs before data can be read,
 * since some programs don't start processing before the write direction is
 * closed.
 */
- (void)closeForWriting;
@end
