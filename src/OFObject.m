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

#define __NO_EXT_QNX

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <unistd.h>

#include <assert.h>

#ifdef __QNX__
# include <sys/syspage.h>
#endif

#import "OFObject.h"
#import "OFTimer.h"
#import "OFThread.h"
#import "OFRunLoop.h"
#import "OFAutoreleasePool.h"

#import "OFAllocFailedException.h"
#import "OFEnumerationMutationException.h"
#import "OFInitializationFailedException.h"
#import "OFInvalidArgumentException.h"
#import "OFMemoryNotPartOfObjectException.h"
#import "OFNotImplementedException.h"
#import "OFOutOfMemoryException.h"
#import "OFOutOfRangeException.h"

#import "autorelease.h"
#import "macros.h"

#if defined(OF_APPLE_RUNTIME) && __OBJC2__
# import <objc/objc-exception.h>
#elif defined(OF_OBJFW_RUNTIME)
# import "runtime.h"
#endif

#ifdef _WIN32
# include <windows.h>
#endif

#import "OFString.h"

#import "instance.h"
#if defined(OF_ATOMIC_OPS)
# import "atomic.h"
#elif defined(OF_THREADS)
# import "threading.h"
#endif

struct pre_ivar {
	int32_t retainCount;
	struct pre_mem *firstMem, *lastMem;
#if !defined(OF_ATOMIC_OPS) && defined(OF_THREADS)
	of_spinlock_t retainCountSpinlock;
#endif
};

struct pre_mem {
	struct pre_mem *prev, *next;
	id owner;
};

#define PRE_IVAR_ALIGN ((sizeof(struct pre_ivar) + \
	(__BIGGEST_ALIGNMENT__ - 1)) & ~(__BIGGEST_ALIGNMENT__ - 1))
#define PRE_IVAR ((struct pre_ivar*)(void*)((char*)self - PRE_IVAR_ALIGN))

#define PRE_MEM_ALIGN ((sizeof(struct pre_mem) + \
	(__BIGGEST_ALIGNMENT__ - 1)) & ~(__BIGGEST_ALIGNMENT__ - 1))
#define PRE_MEM(mem) ((struct pre_mem*)(void*)((char*)mem - PRE_MEM_ALIGN))

static struct {
	Class isa;
} alloc_failed_exception;

size_t of_pagesize;
size_t of_num_cpus;

#if !defined(OF_APPLE_RUNTIME) || defined(__OBJC2__)
static void
uncaught_exception_handler(id exception)
{
	fprintf(stderr, "\nRuntime error: Unhandled exception:\n%s\n",
	    [[exception description] UTF8String]);
	abort();
}
#endif

static void
enumeration_mutation_handler(id object)
{
	@throw [OFEnumerationMutationException
	    exceptionWithClass: [object class]
			object: object];
}

#ifdef OF_OBJFW_RUNTIME
static id
method_not_found_handler(id obj, SEL sel, ...)
{
	fprintf(stderr, "Runtime error: Selector %s is not implemented in "
	    "class %s!\n", sel_getName(sel),
	    class_getName(object_getClass(obj)));
	abort();
}

static IMP
forward_handler(id obj, SEL sel)
{
	if (class_isMetaClass(object_getClass(obj))) {
		if (![obj respondsToSelector: @selector(resolveClassMethod:)])
			return method_not_found_handler;

		if (![obj resolveClassMethod: sel])
			return method_not_found_handler;

		if (![obj respondsToSelector: sel]) {
			fprintf(stderr, "Runtime error: [%s "
			    "resolveClassMethod: %s] returned YES without "
			    "adding the method!\n", class_getName(obj),
			    sel_getName(sel));
			abort();
		}
	} else {
		Class c = object_getClass(obj);

		if (![c respondsToSelector: @selector(resolveInstanceMethod:)])
			return method_not_found_handler;

		if (![c resolveInstanceMethod: sel])
			return method_not_found_handler;

		if (![obj respondsToSelector: sel]) {
			fprintf(stderr, "Runtime error: [%s "
			    "resolveInstanceMethod: %s] returned YES without "
			    "adding the method!\n",
			    class_getName(object_getClass(obj)),
			    sel_getName(sel));
			abort();
		}
	}

	return objc_msg_lookup(obj, sel);
}
#endif

#ifndef HAVE_OBJC_ENUMERATIONMUTATION
void
objc_enumerationMutation(id object)
{
	enumeration_mutation_handler(object);
}
#endif

id
of_alloc_object(Class class, size_t extraSize, size_t extraAlignment,
    void **extra)
{
	OFObject *instance;
	size_t instanceSize;

	instanceSize = class_getInstanceSize(class);

	if OF_UNLIKELY (extraAlignment > 0)
		extraAlignment = ((instanceSize + extraAlignment - 1) &
		    ~(extraAlignment - 1)) - extraAlignment;

	instance = malloc(PRE_IVAR_ALIGN + instanceSize +
	    extraAlignment + extraSize);

	if OF_UNLIKELY (instance == nil) {
		alloc_failed_exception.isa = [OFAllocFailedException class];
		@throw (id)&alloc_failed_exception;
	}

	((struct pre_ivar*)instance)->retainCount = 1;
	((struct pre_ivar*)instance)->firstMem = NULL;
	((struct pre_ivar*)instance)->lastMem = NULL;

#if !defined(OF_ATOMIC_OPS) && defined(OF_THREADS)
	if OF_UNLIKELY (!of_spinlock_new(
	    &((struct pre_ivar*)instance)->retainCountSpinlock)) {
		free(instance);
		@throw [OFInitializationFailedException
		    exceptionWithClass: class];
	}
#endif

	instance = (OFObject*)((char*)instance + PRE_IVAR_ALIGN);

	memset(instance, 0, instanceSize);

	if (!objc_constructInstance(class, instance)) {
		free((char*)instance - PRE_IVAR_ALIGN);
		@throw [OFInitializationFailedException
		    exceptionWithClass: class];
	}

	if OF_UNLIKELY (extra != NULL)
		*extra = (char*)instance + instanceSize + extraAlignment;

	return instance;
}

const char*
_NSPrintForDebugger(id object)
{
	return [[object description]
	    cStringWithEncoding: OF_STRING_ENCODING_NATIVE];
}

/* References for static linking */
void _references_to_categories_of_OFObject(void)
{
	_OFObject_Serialization_reference = 1;
}

@implementation OFObject
+ (void)load
{
#if !defined(OF_APPLE_RUNTIME) || defined(__OBJC2__)
	objc_setUncaughtExceptionHandler(uncaught_exception_handler);
#endif

#ifdef OF_OBJFW_RUNTIME
	objc_forward_handler = forward_handler;
#endif

#ifdef HAVE_OBJC_ENUMERATIONMUTATION
	objc_setEnumerationMutationHandler(enumeration_mutation_handler);
#endif

#if defined(_WIN32)
	SYSTEM_INFO si;
	GetSystemInfo(&si);
	of_pagesize = si.dwPageSize;
	of_num_cpus = si.dwNumberOfProcessors;
#elif defined(__QNX__)
	if ((of_pagesize = sysconf(_SC_PAGESIZE)) < 1)
		of_pagesize = 4096;
	of_num_cpus = _syspage_ptr->num_cpu;
#else
# ifdef _SC_PAGESIZE
	if ((of_pagesize = sysconf(_SC_PAGESIZE)) < 1)
# endif
		of_pagesize = 4096;
# ifdef _SC_NPROCESSORS_CONF
	if ((of_num_cpus = sysconf(_SC_NPROCESSORS_CONF)) < 1)
# endif
		of_num_cpus = 1;
#endif
}

+ (void)initialize
{
}

+ alloc
{
	return of_alloc_object(self, 0, 0, NULL);
}

+ new
{
	return [[self alloc] init];
}

+ (Class)class
{
	return self;
}

+ (OFString*)className
{
	return [OFString stringWithCString: class_getName(self)
				  encoding: OF_STRING_ENCODING_ASCII];
}

+ (BOOL)isSubclassOfClass: (Class)class
{
	Class iter;

	for (iter = self; iter != Nil; iter = class_getSuperclass(iter))
		if (iter == class)
			return YES;

	return NO;
}

+ (Class)superclass
{
	return class_getSuperclass(self);
}

+ (BOOL)instancesRespondToSelector: (SEL)selector
{
	return class_respondsToSelector(self, selector);
}

+ (BOOL)conformsToProtocol: (Protocol*)protocol
{
	Class c;

	for (c = self; c != Nil; c = class_getSuperclass(c))
		if (class_conformsToProtocol(c, protocol))
			return YES;

	return NO;
}

+ (IMP)instanceMethodForSelector: (SEL)selector
{
	return class_getMethodImplementation(self, selector);
}

+ (const char*)typeEncodingForInstanceSelector: (SEL)selector
{
#if defined(OF_OBJFW_RUNTIME)
	const char *ret;

	if ((ret = objc_get_type_encoding(self, selector)) == NULL)
		@throw [OFNotImplementedException exceptionWithClass: self
							    selector: selector];

	return ret;
#else
	Method m;
	const char *ret;

	if ((m = class_getInstanceMethod(self, selector)) == NULL ||
	    (ret = method_getTypeEncoding(m)) == NULL)
		@throw [OFNotImplementedException exceptionWithClass: self
							    selector: selector];

	return ret;
#endif
}

+ (OFString*)description
{
	return [self className];
}

+ (IMP)replaceClassMethod: (SEL)selector
      withMethodFromClass: (Class)class
{
	IMP newImp;
	const char *typeEncoding;

	newImp = [class methodForSelector: selector];
	typeEncoding = [class typeEncodingForSelector: selector];

	return [self replaceClassMethod: selector
		     withImplementation: newImp
			   typeEncoding: typeEncoding];
}

+ (IMP)replaceInstanceMethod: (SEL)selector
	 withMethodFromClass: (Class)class
{
	IMP newImp;
	const char *typeEncoding;

	newImp = [class instanceMethodForSelector: selector];
	typeEncoding = [class typeEncodingForInstanceSelector: selector];

	return [self replaceInstanceMethod: selector
			withImplementation: newImp
			      typeEncoding: typeEncoding];
}

+ (IMP)replaceInstanceMethod: (SEL)selector
	  withImplementation: (IMP)implementation
		typeEncoding: (const char*)typeEncoding
{
	return class_replaceMethod(self, selector, implementation,
	    typeEncoding);
}

+ (IMP)replaceClassMethod: (SEL)selector
       withImplementation: (IMP)implementation
	     typeEncoding: (const char*)typeEncoding
{
	return class_replaceMethod(object_getClass(self), selector,
	    implementation, typeEncoding);
}

+ (void)inheritMethodsFromClass: (Class)class
{
	Class superclass = [self superclass];

	if ([self isSubclassOfClass: class])
		return;

#if defined(OF_APPLE_RUNTIME)
	Method *methodList;
	unsigned i, count;

	methodList = class_copyMethodList(object_getClass(class), &count);
	@try {
		for (i = 0; i < count; i++) {
			SEL selector = method_getName(methodList[i]);

			/*
			 * Don't replace methods implemented in receiving class.
			 */
			if ([self methodForSelector: selector] !=
			    [superclass methodForSelector: selector])
				continue;

			[self replaceClassMethod: selector
			     withMethodFromClass: class];
		}
	} @finally {
		free(methodList);
	}

	methodList = class_copyMethodList(class, &count);
	@try {
		for (i = 0; i < count; i++) {
			SEL selector = method_getName(methodList[i]);

			/*
			 * Don't replace methods implemented in receiving class.
			 */
			if ([self instanceMethodForSelector: selector] !=
			    [superclass instanceMethodForSelector: selector])
				continue;

			[self replaceInstanceMethod: selector
				withMethodFromClass: class];
		}
	} @finally {
		free(methodList);
	}
#elif defined(OF_OBJFW_RUNTIME)
	struct objc_method_list *methodlist;

	for (methodlist = object_getClass(class)->methodlist;
	    methodlist != NULL; methodlist = methodlist->next) {
		int i;

		for (i = 0; i < methodlist->count; i++) {
			SEL selector = (SEL)&methodlist->methods[i].sel;

			/*
			 * Don't replace methods implemented in receiving class.
			 */
			if ([self methodForSelector: selector] !=
			    [superclass methodForSelector: selector])
				continue;

			[self replaceClassMethod: selector
			     withMethodFromClass: class];
		}
	}

	for (methodlist = class->methodlist; methodlist != NULL;
	    methodlist = methodlist->next) {
		int i;

		for (i = 0; i < methodlist->count; i++) {
			SEL selector = (SEL)&methodlist->methods[i].sel;

			/*
			 * Don't replace methods implemented in receiving class.
			 */
			if ([self instanceMethodForSelector: selector] !=
			    [superclass instanceMethodForSelector: selector])
				continue;

			[self replaceInstanceMethod: selector
				withMethodFromClass: class];
		}
	}
#endif

	[self inheritMethodsFromClass: [class superclass]];
}

+ (BOOL)resolveClassMethod: (SEL)selector
{
	return NO;
}

+ (BOOL)resolveInstanceMethod: (SEL)selector
{
	return NO;
}

- init
{
	return self;
}

- (Class)class
{
	return object_getClass(self);
}

- (OFString*)className
{
	return [OFString stringWithCString: object_getClassName(self)
				  encoding: OF_STRING_ENCODING_ASCII];
}

- (BOOL)isKindOfClass: (Class)class
{
	Class iter;

	for (iter = object_getClass(self); iter != Nil;
	    iter = class_getSuperclass(iter))
		if (iter == class)
			return YES;

	return NO;
}

- (BOOL)isMemberOfClass: (Class)class
{
	return (object_getClass(self) == class);
}

- (BOOL)respondsToSelector: (SEL)selector
{
	return class_respondsToSelector(object_getClass(self), selector);
}

- (BOOL)conformsToProtocol: (Protocol*)protocol
{
	return [object_getClass(self) conformsToProtocol: protocol];
}

- (IMP)methodForSelector: (SEL)selector
{
	return class_getMethodImplementation(object_getClass(self), selector);
}

- (id)performSelector: (SEL)selector
{
	id (*imp)(id, SEL) = (id(*)(id, SEL))[self methodForSelector: selector];

	return imp(self, selector);
}

- (id)performSelector: (SEL)selector
	   withObject: (id)object
{
	id (*imp)(id, SEL, id) =
	    (id(*)(id, SEL, id))[self methodForSelector: selector];

	return imp(self, selector, object);
}

- (id)performSelector: (SEL)selector
	   withObject: (id)object1
	   withObject: (id)object2
{
	id (*imp)(id, SEL, id, id) =
	    (id(*)(id, SEL, id, id))[self methodForSelector: selector];

	return imp(self, selector, object1, object2);
}

- (void)performSelector: (SEL)selector
	     afterDelay: (double)delay
{
	void *pool = objc_autoreleasePoolPush();

	[OFTimer scheduledTimerWithTimeInterval: delay
					 target: self
				       selector: selector
					repeats: NO];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	     withObject: (id)object
	     afterDelay: (double)delay
{
	void *pool = objc_autoreleasePoolPush();

	[OFTimer scheduledTimerWithTimeInterval: delay
					 target: self
				       selector: selector
					 object: object
					repeats: NO];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	     withObject: (id)object1
	     withObject: (id)object2
	     afterDelay: (double)delay
{
	void *pool = objc_autoreleasePoolPush();

	[OFTimer scheduledTimerWithTimeInterval: delay
					 target: self
				       selector: selector
					 object: object1
					 object: object2
					repeats: NO];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	       onThread: (OFThread*)thread
	  waitUntilDone: (BOOL)waitUntilDone
{
	void *pool = objc_autoreleasePoolPush();
	OFTimer *timer = [OFTimer timerWithTimeInterval: 0
						 target: self
					       selector: selector
						repeats: NO];
	[[thread runLoop] addTimer: timer];

	if (waitUntilDone)
		[timer waitUntilDone];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	       onThread: (OFThread*)thread
	     withObject: (id)object
	  waitUntilDone: (BOOL)waitUntilDone
{
	void *pool = objc_autoreleasePoolPush();
	OFTimer *timer = [OFTimer timerWithTimeInterval: 0
						 target: self
					       selector: selector
						 object: object
						repeats: NO];
	[[thread runLoop] addTimer: timer];

	if (waitUntilDone)
		[timer waitUntilDone];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	       onThread: (OFThread*)thread
	     withObject: (id)object1
	     withObject: (id)object2
	  waitUntilDone: (BOOL)waitUntilDone
{
	void *pool = objc_autoreleasePoolPush();
	OFTimer *timer = [OFTimer timerWithTimeInterval: 0
						 target: self
					       selector: selector
						 object: object1
						 object: object2
						repeats: NO];
	[[thread runLoop] addTimer: timer];

	if (waitUntilDone)
		[timer waitUntilDone];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelectorOnMainThread: (SEL)selector
		      waitUntilDone: (BOOL)waitUntilDone
{
	void *pool = objc_autoreleasePoolPush();
	OFTimer *timer = [OFTimer timerWithTimeInterval: 0
						 target: self
					       selector: selector
						repeats: NO];
	[[OFRunLoop mainRunLoop] addTimer: timer];

	if (waitUntilDone)
		[timer waitUntilDone];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelectorOnMainThread: (SEL)selector
			 withObject: (id)object
		      waitUntilDone: (BOOL)waitUntilDone
{
	void *pool = objc_autoreleasePoolPush();
	OFTimer *timer = [OFTimer timerWithTimeInterval: 0
						 target: self
					       selector: selector
						 object: object
						repeats: NO];
	[[OFRunLoop mainRunLoop] addTimer: timer];

	if (waitUntilDone)
		[timer waitUntilDone];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelectorOnMainThread: (SEL)selector
			 withObject: (id)object1
			 withObject: (id)object2
		      waitUntilDone: (BOOL)waitUntilDone
{
	void *pool = objc_autoreleasePoolPush();
	OFTimer *timer = [OFTimer timerWithTimeInterval: 0
						 target: self
					       selector: selector
						 object: object1
						 object: object2
						repeats: NO];
	[[OFRunLoop mainRunLoop] addTimer: timer];

	if (waitUntilDone)
		[timer waitUntilDone];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	       onThread: (OFThread*)thread
	     afterDelay: (double)delay
{
	void *pool = objc_autoreleasePoolPush();

	[[thread runLoop] addTimer: [OFTimer timerWithTimeInterval: delay
							    target: self
							  selector: selector
							   repeats: NO]];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	       onThread: (OFThread*)thread
	     withObject: (id)object
	     afterDelay: (double)delay
{
	void *pool = objc_autoreleasePoolPush();

	[[thread runLoop] addTimer: [OFTimer timerWithTimeInterval: delay
							    target: self
							  selector: selector
							    object: object
							   repeats: NO]];

	objc_autoreleasePoolPop(pool);
}

- (void)performSelector: (SEL)selector
	       onThread: (OFThread*)thread
	     withObject: (id)object1
	     withObject: (id)object2
	     afterDelay: (double)delay
{
	void *pool = objc_autoreleasePoolPush();

	[[thread runLoop] addTimer: [OFTimer timerWithTimeInterval: delay
							    target: self
							  selector: selector
							    object: object1
							    object: object2
							   repeats: NO]];

	objc_autoreleasePoolPop(pool);
}

- (const char*)typeEncodingForSelector: (SEL)selector
{
#if defined(OF_OBJFW_RUNTIME)
	const char *ret;

	if ((ret = objc_get_type_encoding(object_getClass(self),
	    selector)) == NULL)
		@throw [OFNotImplementedException
		    exceptionWithClass: [self class]
			      selector: selector];

	return ret;
#else
	Method m;
	const char *ret;

	if ((m = class_getInstanceMethod(object_getClass(self),
	    selector)) == NULL || (ret = method_getTypeEncoding(m)) == NULL)
		@throw [OFNotImplementedException
		    exceptionWithClass: [self class]
			      selector: selector];

	return ret;
#endif
}

- (BOOL)isEqual: (id)object
{
	/* Classes containing data should reimplement this! */
	return (self == object);
}

- (uint32_t)hash
{
	/* Classes containing data should reimplement this! */
	return (uint32_t)(uintptr_t)self;
}

- (OFString*)description
{
	/* Classes containing data should reimplement this! */
	return [OFString stringWithFormat: @"<%@: %p>", [self className], self];
}

- (void*)allocMemoryWithSize: (size_t)size
{
	void *pointer;
	struct pre_mem *preMem;

	if OF_UNLIKELY (size > SIZE_MAX - PRE_IVAR_ALIGN)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	if OF_UNLIKELY ((pointer = malloc(PRE_MEM_ALIGN + size)) == NULL)
		@throw [OFOutOfMemoryException exceptionWithClass: [self class]
						    requestedSize: size];
	preMem = pointer;

	preMem->owner = self;
	preMem->prev = PRE_IVAR->lastMem;
	preMem->next = NULL;

	if OF_LIKELY (PRE_IVAR->lastMem != NULL)
		PRE_IVAR->lastMem->next = preMem;

	if OF_UNLIKELY (PRE_IVAR->firstMem == NULL)
		PRE_IVAR->firstMem = preMem;
	PRE_IVAR->lastMem = preMem;

	return (char*)pointer + PRE_MEM_ALIGN;
}

- (void*)allocMemoryWithSize: (size_t)size
		       count: (size_t)count
{
	if OF_UNLIKELY (size == 0 || count == 0)
		return NULL;

	if OF_UNLIKELY (count > SIZE_MAX / size)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	return [self allocMemoryWithSize: size * count];
}

- (void*)resizeMemory: (void*)pointer
		 size: (size_t)size
{
	void *new;
	struct pre_mem *preMem;

	if OF_UNLIKELY (pointer == NULL)
		return [self allocMemoryWithSize: size];

	if OF_UNLIKELY (size == 0) {
		[self freeMemory: pointer];
		return NULL;
	}

	if OF_UNLIKELY (PRE_MEM(pointer)->owner != self)
		@throw [OFMemoryNotPartOfObjectException
		    exceptionWithClass: [self class]
			       pointer: pointer];

	if OF_UNLIKELY ((new = realloc(PRE_MEM(pointer),
	    PRE_MEM_ALIGN + size)) == NULL)
		@throw [OFOutOfMemoryException exceptionWithClass: [self class]
						    requestedSize: size];
	preMem = new;

	if OF_UNLIKELY (preMem != PRE_MEM(pointer)) {
		if OF_LIKELY (preMem->prev != NULL)
			preMem->prev->next = preMem;
		if OF_LIKELY (preMem->next != NULL)
			preMem->next->prev = preMem;

		if OF_UNLIKELY (PRE_IVAR->firstMem == PRE_MEM(pointer))
			PRE_IVAR->firstMem = preMem;
		if OF_UNLIKELY (PRE_IVAR->lastMem == PRE_MEM(pointer))
			PRE_IVAR->lastMem = preMem;
	}

	return (char*)new + PRE_MEM_ALIGN;
}

- (void*)resizeMemory: (void*)pointer
		 size: (size_t)size
		count: (size_t)count
{
	if OF_UNLIKELY (pointer == NULL)
		return [self allocMemoryWithSize: size
					   count: count];

	if OF_UNLIKELY (size == 0 || count == 0) {
		[self freeMemory: pointer];
		return NULL;
	}

	if OF_UNLIKELY (count > SIZE_MAX / size)
		@throw [OFOutOfRangeException exceptionWithClass: [self class]];

	return [self resizeMemory: pointer
			     size: size * count];
}

- (void)freeMemory: (void*)pointer
{
	if OF_UNLIKELY (pointer == NULL)
		return;

	if OF_UNLIKELY (PRE_MEM(pointer)->owner != self)
		@throw [OFMemoryNotPartOfObjectException
		    exceptionWithClass: [self class]
			       pointer: pointer];

	if OF_LIKELY (PRE_MEM(pointer)->prev != NULL)
		PRE_MEM(pointer)->prev->next = PRE_MEM(pointer)->next;
	if OF_LIKELY (PRE_MEM(pointer)->next != NULL)
		PRE_MEM(pointer)->next->prev = PRE_MEM(pointer)->prev;

	if OF_UNLIKELY (PRE_IVAR->firstMem == PRE_MEM(pointer))
		PRE_IVAR->firstMem = PRE_MEM(pointer)->next;
	if OF_UNLIKELY (PRE_IVAR->lastMem == PRE_MEM(pointer))
		PRE_IVAR->lastMem = PRE_MEM(pointer)->prev;

	/* To detect double-free */
	PRE_MEM(pointer)->owner = nil;

	free(PRE_MEM(pointer));
}

- retain
{
#if defined(OF_ATOMIC_OPS)
	of_atomic_inc_32(&PRE_IVAR->retainCount);
#elif defined(OF_THREADS)
	OF_ENSURE(of_spinlock_lock(&PRE_IVAR->retainCountSpinlock));
	PRE_IVAR->retainCount++;
	OF_ENSURE(of_spinlock_unlock(&PRE_IVAR->retainCountSspinlock));
#else
	PRE_IVAR->retainCount++;
#endif

	return self;
}

- (unsigned int)retainCount
{
	assert(PRE_IVAR->retainCount >= 0);
	return PRE_IVAR->retainCount;
}

- (void)release
{
#if defined(OF_ATOMIC_OPS)
	if (of_atomic_dec_32(&PRE_IVAR->retainCount) <= 0)
		[self dealloc];
#elif defined(OF_THREADS)
	size_t c;

	OF_ENSURE(of_spinlock_lock(&PRE_IVAR->retainCountSpinlock));
	c = --PRE_IVAR->retainCount;
	OF_ENSURE(of_spinlock_unlock(&PRE_IVAR->retainCountSpinlock));

	if (c == 0)
		[self dealloc];
#else
	if (--PRE_IVAR->retainCount == 0)
		[self dealloc];
#endif
}

- autorelease
{
	return _objc_rootAutorelease(self);
}

- self
{
	return self;
}

- (BOOL)isProxy
{
	return NO;
}

- (void)dealloc
{
	struct pre_mem *iter;

	objc_destructInstance(self);

	iter = PRE_IVAR->firstMem;
	while (iter != NULL) {
		struct pre_mem *next = iter->next;

		/*
		 * We can use owner as a sentinel to prevent exploitation in
		 * case there is a buffer underflow somewhere.
		 */
		if OF_UNLIKELY (iter->owner != self)
			abort();

		free(iter);

		iter = next;
	}

	free((char*)self - PRE_IVAR_ALIGN);
}

/* Required to use properties with the Apple runtime */
- copyWithZone: (void*)zone
{
	if OF_UNLIKELY (zone != NULL)
		@throw [OFNotImplementedException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	return [(id)self copy];
}

- mutableCopyWithZone: (void*)zone
{
	if OF_UNLIKELY (zone != NULL)
		@throw [OFNotImplementedException
		    exceptionWithClass: [self class]
			      selector: _cmd];

	return [(id)self mutableCopy];
}

/*
 * Those are needed as the root class is the superclass of the root class's
 * metaclass and thus instance methods can be sent to class objects as well.
 */
+ (void*)allocMemoryWithSize: (size_t)size
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ (void*)allocMemoryWithSize: (size_t)size
		       count: (size_t)count
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ (void*)resizeMemory: (void*)pointer
		 size: (size_t)size
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ (void*)resizeMemory: (void*)pointer
		 size: (size_t)size
		count: (size_t)count
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ (void)freeMemory: (void*)pointer
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ retain
{
	return self;
}

+ autorelease
{
	return self;
}

+ (unsigned int)retainCount
{
	return OF_RETAIN_COUNT_MAX;
}

+ (void)release
{
}

+ (void)dealloc
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ copyWithZone: (void*)zone
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}

+ mutableCopyWithZone: (void*)zone
{
	@throw [OFNotImplementedException exceptionWithClass: self
						    selector: _cmd];
}
@end
