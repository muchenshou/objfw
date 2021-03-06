AC_INIT(ObjFW, 0.8-dev, js@webkeks.org)
AC_CONFIG_SRCDIR(src)

AS_IF([test x"$host" = x"psp"], [
	OBJCFLAGS="-G0 $OBJCFLAGS"
	LIBS="$LIBS -lpspdebug -lpspdisplay -lpspge -lpspctrl -lpspsdk -lc"
	LIBS="$LIBS -lpspnet -lpspnet_inet -lpspnet_apctl -lpspnet_resolver"
	LIBS="$LIBS -lpsputility -lpspuser -lpspkernel"
])

AC_CANONICAL_HOST

AC_LANG([Objective C])
AC_PROG_OBJC([clang gcc])
AC_PROG_OBJCPP
AC_PROG_LN_S
AC_PROG_INSTALL
AC_PROG_EGREP

CPP="$OBJCPP"
CPPFLAGS="$CPPFLAGS $OBJCPPFLAGS"
OBJCFLAGS="$OBJCFLAGS -Wall -fexceptions -fobjc-exceptions -funwind-tables"
OBJCFLAGS="$OBJCFLAGS -fconstant-string-class=OFConstantString"

AX_CHECK_COMPILER_FLAGS(-std=gnu99, [OBJCFLAGS="$OBJCFLAGS -std=gnu99"])
case $OBJC in
	*clang*)
		;;
	*)
		AX_CHECK_COMPILER_FLAGS([-fgnu89-inline -Werror],
			[OBJCFLAGS="$OBJCFLAGS -fgnu89-inline"])
		;;
esac
AX_CHECK_COMPILER_FLAGS(-pipe, [OBJCFLAGS="$OBJCFLAGS -pipe"])
AX_CHECK_COMPILER_FLAGS(-fno-common, [OBJCFLAGS="$OBJCFLAGS -fno-common"])
AX_CHECK_COMPILER_FLAGS(-fno-constant-cfstrings, [
	OBJCFLAGS="$OBJCFLAGS -fno-constant-cfstrings"
	AC_SUBST(NO_CONST_CFSTRINGS, "-fno-constant-cfstrings")
])
AX_CHECK_COMPILER_FLAGS(-Wshorten-64-to-32,
	[OBJCFLAGS="$OBJCFLAGS -Wshorten-64-to-32"])
AX_CHECK_COMPILER_FLAGS(-Wsemicolon-before-method-body,
	[OBJCFLAGS="$OBJCFLAGS -Wsemicolon-before-method-body"])
AX_CHECK_COMPILER_FLAGS(-Wno-objc-root-class,
	[OBJCFLAGS="$OBJCFLAGS -Wno-objc-root-class"])

AC_MSG_CHECKING(whether Objective C compiler supports properties)
AC_TRY_COMPILE([
	@interface Foo
	{
		id bar;
	}

	@property (retain, nonatomic) id bar;
	@end
], [
	Foo *foo = (id)0;
	[foo setBar: (id)0];
	[foo bar];
], [
	AC_SUBST(PROPERTIESTESTS_M, "PropertiesTests.m")
	AC_MSG_RESULT(yes)
], [
	AC_MSG_RESULT(no)
])

AC_MSG_CHECKING(whether Objective C compiler supports blocks)
old_OBJCFLAGS="$OBJCFLAGS"
OBJCFLAGS="$OBJCFLAGS -fblocks"
AC_TRY_COMPILE([], [
	int (^foo)(int bar);
	foo = ^ (int bar) { return 0; }
], [
	AC_SUBST(BLOCKS_FLAGS, "-fblocks")
	AC_SUBST(OFBLOCKTESTS_M, "OFBlockTests.m")
	AC_MSG_RESULT(yes)
], [
	AC_MSG_RESULT(no)
	OBJCFLAGS="$old_OBJCFLAGS"
])

AC_CHECK_TOOL(AR, ar)
AC_PROG_RANLIB
AC_ARG_ENABLE(shared,
	AS_HELP_STRING([--disable-shared], [do not build shared library]))
AS_IF([test x"$enable_shared" != x"no"], [
	BUILDSYS_SHARED_LIB
	AC_SUBST(OBJFW_SHARED_LIB, "${LIB_PREFIX}objfw${LIB_SUFFIX}")
	AC_SUBST(EXCEPTIONS_LIB_A, "exceptions.lib.a")
	AC_SUBST(EXCEPTIONS_EXCEPTIONS_LIB_A, "exceptions/exceptions.lib.a")
])
AC_ARG_ENABLE(static, AS_HELP_STRING([--enable-static], [build static library]))
AS_IF([test x"$enable_static" = x"yes" -o x"$enable_shared" = x"no"], [
	AC_SUBST(OBJFW_STATIC_LIB, "libobjfw.a")
	AC_SUBST(EXCEPTIONS_A, "exceptions.a")
	AC_SUBST(EXCEPTIONS_EXCEPTIONS_A, "exceptions/exceptions.a")
])

AC_DEFINE_UNQUOTED(PLUGIN_SUFFIX, "$PLUGIN_SUFFIX", [Suffix for plugins])
AS_IF([test x"$PLUGIN_SUFFIX" != x""], [
	AC_SUBST(OFPLUGIN_M, "OFPlugin.m")
	AC_SUBST(OFPLUGINTESTS_M, "OFPluginTests.m")
	AC_SUBST(TESTPLUGIN, "plugin")
	AC_DEFINE(OF_PLUGINS, 1, [Whether we have plugin support])
	AC_SUBST(OFPLUGINS_DEF, "-DOF_PLUGINS")
])

objc_runtime="ObjFW runtime"
AC_CHECK_HEADER(objc/objc.h)
AC_MSG_CHECKING(which Objective C runtime to use)
AC_ARG_ENABLE(runtime,
	AS_HELP_STRING([--enable-runtime], [use the included runtime]))
AC_ARG_ENABLE(seluid16,
	AS_HELP_STRING([--enable-seluid16],
		[use only 16 bit for selectors UIDs]))
AS_IF([test x"$enable_runtime" != x"yes"], [
	AS_IF([test x"$ac_cv_header_objc_objc_h" = x"yes"], [
		dnl TODO: This is ugly. Let's think of a better check.
		AC_EGREP_CPP(yes, [
			#import <objc/objc.h>
			#ifdef __objc_INCLUDE_GNU
			yes
			#endif
		], [
			dnl We don't want the GNU runtime
			true
		], [
			objc_runtime="Apple runtime"
		])
	])
])
AC_MSG_RESULT($objc_runtime)

case $objc_runtime in
	"ObjFW runtime")
		AC_DEFINE(OF_OBJFW_RUNTIME, 1,
			[Whether we use the ObjFW runtime])

		AC_MSG_CHECKING([whether -fobjc-runtime=objfw is supported])

		old_OBJCFLAGS="$OBJCFLAGS"
		OBJCFLAGS="$OBJCFLAGS -fobjc-runtime=objfw"
		AC_TRY_LINK([
			@interface Test
			+ (void)test;
			@end

			@implementation Test
			+ (void)test
			{
			}
			@end

			void*
			objc_msg_lookup(void *obj, void *sel)
			{
				return (void*)0;
			}

			void
			__objc_exec_class(void *module)
			{
			}
		], [
			[Test test];
		], [
			RUNTIME_FLAGS="-fobjc-runtime=objfw"
			AC_MSG_RESULT(yes)
		], [
			RUNTIME_FLAGS="-fgnu-runtime"
			OBJCFLAGS="$old_OBJCFLAGS -fgnu-runtime"
			AC_MSG_RESULT(no)
			old_compiler="yes"

			AX_CHECK_COMPILER_FLAGS(-fno-objc-nonfragile-abi, [
				flag="-fno-objc-nonfragile-abi"
				OBJCFLAGS="$OBJCFLAGS $flag"
				RUNTIME_FLAGS="$RUNTIME_FLAGS $flag"
			])
		])

		AC_SUBST(RUNTIME, "runtime")
		AC_SUBST(RUNTIME_FLAGS)

		if test x"$enable_shared" != x"no"; then
			AC_SUBST(RUNTIME_LIB_A, "runtime.lib.a")
			AC_SUBST(RUNTIME_RUNTIME_LIB_A, "runtime/runtime.lib.a")
		fi
		if test x"$enable_static" = x"yes" \
		    -o x"$enable_shared" = x"no"; then
			AC_SUBST(RUNTIME_A, "runtime.a")
			AC_SUBST(RUNTIME_RUNTIME_A, "runtime/runtime.a")
		fi

		AC_EGREP_CPP(yes, [
			#if defined(__amd64__) || defined(__x86_64__)
			# ifdef __ELF__
			yes
			# endif
			#endif
		], [
			AC_SUBST(LOOKUP_S, lookup-amd64-elf.S)
			AC_DEFINE(OF_ASM_LOOKUP, 1,
				[Whether to use assembly for lookup])
		], [
			AC_EGREP_CPP(yes, [
				#if defined(__i386__) && defined(__ELF__)
				yes
				#endif
			], [
				AC_SUBST(LOOKUP_S, lookup-x86-elf.S)
				AC_DEFINE(OF_ASM_LOOKUP, 1,
					[Whether to use assembly for lookup])
			])
		])

		AC_EGREP_CPP(yes, [
			#if defined(__amd64__) || defined(__x86_64__)
			# ifdef __MACH__
			yes
			# endif
			#endif
		], [
			AC_SUBST(LOOKUP_S, lookup-amd64-macho.S)
			AC_DEFINE(OF_ASM_LOOKUP, 1,
				[Whether to use assembly for lookup])
		])

		AC_EGREP_CPP(yes, [
			#if defined(__ppc__) || defined(__PPC__)
			# ifdef __ELF__
			yes
			# endif
			#endif
		], [
			AC_SUBST(LOOKUP_S, lookup-ppc-elf.S)
			AC_DEFINE(OF_ASM_LOOKUP, 1,
				[Whether to use assembly for lookup])
		])

		AC_EGREP_CPP(yes, [
			#if defined(__arm__) || defined(__ARM__)
			# ifdef __ELF__
			yes
			# endif
			#endif
		], [
			AC_SUBST(LOOKUP_S, lookup-arm-elf.S)
			AC_DEFINE(OF_ASM_LOOKUP, 1,
				[Whether to use assembly for lookup])
		])

		AS_IF([test x"$enable_seluid16" = x"yes"], [
			AC_DEFINE(OF_SELUID16, 1,
				[Whether to use 16 bit selector UIDs])
		])
		;;
	"Apple runtime")
		AC_DEFINE(OF_APPLE_RUNTIME, 1,
			[Whether we use the Apple ObjC runtime])

		AC_CHECK_LIB(objc, objc_msgSend, [
			LIBS="-lobjc $LIBS"
		], [
			AC_MSG_ERROR([libobjc not found!])
		])
		;;
esac

AC_CHECK_FUNC(objc_constructInstance, [], [
	AC_SUBST(INSTANCE_M, "instance.m")
])

AC_CHECK_FUNC(objc_autoreleasePoolPush, [], [
	AC_SUBST(AUTORELEASE_M, "autorelease.m")
])

AC_CHECK_FUNC(objc_enumerationMutation, [
	AC_DEFINE(HAVE_OBJC_ENUMERATIONMUTATION, 1,
		[Whether we have objc_enumerationMutation])
])

case "$host_os" in
	darwin*)
		AC_SUBST(LDFLAGS_REEXPORT, ["-Wl,-reexport-lobjfw"])
		AS_IF([test x"$objc_runtime" = x"Apple runtime"], [
			AC_SUBST(REEXPORT_LIBOBJC, ["-Wl,-reexport-lobjc"])
			tmp="-Xarch_x86_64 -Wl,-alias_list,mach_alias_list"
			AC_SUBST(MACH_ALIAS_LIST, $tmp)
		])
		;;
esac

AC_C_BIGENDIAN([
	AC_DEFINE(OF_BIG_ENDIAN, 1, [Whether we are big endian])
])

AC_MSG_CHECKING(for SIZE_MAX)
AC_EGREP_CPP(yes, [
	#include <stdint.h>
	#include <limits.h>

	#ifdef SIZE_MAX
	yes
	#endif
], [
	AC_MSG_RESULT(yes)
], [
	AC_MSG_RESULT(no)
	AC_MSG_CHECKING(for SIZE_T_MAX)
	AC_EGREP_CPP(yes, [
		#include <stdint.h>
		#include <limits.h>

		#ifdef SIZE_T_MAX
		yes
		#endif
	], [
		AC_MSG_RESULT(yes)
		size_max="SIZE_T_MAX"
	], [
		AC_MSG_RESULT(no)
		size_max="(~(size_t)0)"
	])
	AC_DEFINE_UNQUOTED(SIZE_MAX, $size_max, [Maximum value for size_t])
])

AC_CHECK_SIZEOF(float)
AC_CHECK_SIZEOF(double)
AS_IF([test x"$ac_cv_sizeof_float" != x"4" -o x"$ac_cv_sizeof_double" != x"8"],
	[AC_MSG_ERROR(
		[Floating point implementation does not conform to IEEE 754!])])

AC_MSG_CHECKING(for floating point endianess)
fp_endianess="unknown"
AC_TRY_COMPILE([
	double endianess = 2.993700760838795055656993580068609688772747263874402942272934826871811872228512759832626847251963763755836687759498519784550143745834860002945223766052808125982053455555265216112722718870586961456110693379343178124592311441022662940307099598578775368547768968914916965731708568179631324904813506101190853720749196062963892799499230635163056742330563321122389331703618066046034494287335316842529021563862331183541255013987734473643350285400060357711238514186776429325214739886098119655678483017894951556639821088508565036657794343031121375178126860889964700274558728491825977274341798997758923017217660272136611938897932105874133412726223468780517578125e-259;
], [
], [
	AS_IF([$EGREP BigEnd conftest.$ac_objext >/dev/null], [
		AC_DEFINE(OF_FLOAT_BIG_ENDIAN, 1,
			[Whether floats are big endian])
		fp_endianess="big endian"
	], [
		AS_IF([$EGREP dnEgiB conftest.$ac_objext >/dev/null], [
			fp_endianess="little endian"
		])
	])
])
AC_MSG_RESULT($fp_endianess)
AS_IF([test x"$fp_endianess" = x"unknown"], [
	AC_MSG_ERROR(
		[Floating point implementation does not conform to IEEE 754!])])

AC_CHECK_LIB(m, fmod, LIBS="$LIBS -lm")

AC_CHECK_FUNC(asprintf, [
	case "$host" in
		*-psp-*)
			dnl asprintf is broken on the PSP, but snprintf works.
			have_asprintf="no"
			AC_SUBST(ASPRINTF_M, "asprintf.m")
			ac_cv_snprintf_useful_ret="yes"
			;;
		*)
			have_asprintf="yes"
			AC_DEFINE(OF_HAVE_ASPRINTF, 1,
				[Whether we have asprintf])
			AC_SUBST(ASPRINTF_DEF, "-DOF_HAVE_ASPRINTF")
		;;
	esac
], [
	have_asprintf="no"
	AC_SUBST(ASPRINTF_M, "asprintf.m")

	AC_MSG_CHECKING(whether snprintf returns something useful)
	AC_CACHE_VAL(ac_cv_snprintf_useful_ret, [
		AC_TRY_RUN([
			#include <stdio.h>

			int
			main()
			{
				return (snprintf(NULL, 0, "asd") == 3 ? 0 : 1);
			}
		], [
			ac_cv_snprintf_useful_ret="yes"
		], [
			ac_cv_snprintf_useful_ret="no"
		], [
			ac_cv_snprintf_useful_ret="no"
		])
	])
	AC_MSG_RESULT($ac_cv_snprintf_useful_ret)
])
test x"$have_asprintf" != x"yes" -a x"$ac_cv_snprintf_useful_ret" != x"yes" && \
	AC_MSG_ERROR(No asprintf and no snprintf returning required space!)

AC_CHECK_LIB(dl, dlopen, LIBS="$LIBS -ldl")

AC_ARG_ENABLE(threads,
	AS_HELP_STRING([--disable-threads], [disable thread support]))
AS_IF([test x"$enable_threads" != x"no"], [
	case "$host_os" in
	mingw*)
		AC_MSG_CHECKING(for threads)
		AC_MSG_RESULT(WinAPI)
		;;
	*)
		ACX_PTHREAD([
			CPPLAGS="$CPPFLAGS $PTHREAD_CFLAGS"
			LIBS="$LIBS $PTHREAD_LIBS"
			AC_DEFINE(OF_HAVE_PTHREADS, 1,
				[Whether we have pthreads])

			AC_TRY_COMPILE([
				#include <pthread.h>
			], [
				pthread_mutexattr_t attr;
				pthread_mutexattr_settype(&attr,
				    PTHREAD_MUTEX_RECURSIVE);
			], [
				AC_DEFINE(OF_HAVE_RECURSIVE_PTHREAD_MUTEXES, 1,
					[If pthread mutexes can be recursive])
			])

			AC_CHECK_FUNC(pthread_spin_lock, [
				AC_DEFINE(OF_HAVE_PTHREAD_SPINLOCKS, 1,
					[Whether we have pthread spinlocks])
			])

			AC_CHECK_FUNC(sched_yield, [
				AC_DEFINE(OF_HAVE_SCHED_YIELD, 1,
					[Whether we have sched_yield])
			])
		], [
			AC_MSG_ERROR(No supported threads found!)
		])
		;;
	esac

	AC_DEFINE(OF_THREADS, 1, [Whether we have threads])
	AC_SUBST(THREADING_SOURCES, "	\
		OFThread.m		\
		OFThreadPool.m		\
		OFTLSKey.m		\
		OFMutex.m		\
		OFRecursiveMutex.m	\
		OFCondition.m		\
	")
	AC_SUBST(OFTHREADTESTS_M, "OFThreadTests.m")
	AC_SUBST(OFHTTPREQUESTTESTS_M, "OFHTTPRequestTests.m")
	AC_SUBST(THREADING_H, "threading.h")

	AC_MSG_CHECKING(whether __thread works)
	AC_TRY_LINK([
		/* It seems __thread is buggy with GCC 4.1 */
		#if __GNUC__ == 4 && __GNUC_MINOR__ < 2
		# error buggy
		#endif

		__thread int x = 0;
	], [
		x++;
	], [
		AC_MSG_RESULT(yes)
		AC_DEFINE(OF_COMPILER_TLS, 1, [Whether __thread works])
	], [
		AC_MSG_RESULT(no)
	])

	atomic_ops="none"

	AC_MSG_CHECKING(whether we have an atomic ops assembly implementation)
	AC_EGREP_CPP(yes, [
		#if defined(__GNUC__) && (defined(__i386__) || \
		    defined(__amd64__) || defined(__x86_64__))
		yes
		#endif
	], [
		AC_MSG_RESULT(yes)
		atomic_ops="assembly implementation"
	], [
		AC_MSG_RESULT(no)
	])

	AC_MSG_CHECKING(whether __sync_* works)
	AC_TRY_LINK([#include <stdint.h>], [
		int32_t i, j;
		if (__sync_add_and_fetch(&i, 1))
			j = __sync_sub_and_fetch(&i, 1);
		while (!__sync_bool_compare_and_swap(&i, 0, 1));
	], [
		AC_MSG_RESULT(yes)
		test x"$atomic_ops" = x"none" && atomic_ops="gcc builtins"
		AC_DEFINE(OF_HAVE_GCC_ATOMIC_OPS, 1,
			[Whether gcc atomic operations are available])
	], [
		AC_MSG_RESULT(no)
	])

	AC_CHECK_HEADER(libkern/OSAtomic.h, [
		test x"$atomic_ops" = x"none" && atomic_ops="libkern/OSAtomic.h"
		AC_DEFINE(OF_HAVE_OSATOMIC, 1,
			[Whether we have libkern/OSAtomic.h])
		AC_CHECK_FUNC(OSAtomicAdd64Barrier, [
			AC_DEFINE(OF_HAVE_OSATOMIC_64, 1,
				[Whether we have OSAtomic*64])
		])
	])
], [
	dnl We can only have one thread - therefore everything is atomic
	atomic_ops="not needed"
])

AC_MSG_CHECKING(for atomic operations)
AS_IF([test x"$atomic_ops" != x"none"], [
	AC_DEFINE(OF_ATOMIC_OPS, 1, [Whether we have atomic operations])
	AC_SUBST(ATOMIC_H, "atomic.h")
])
AC_MSG_RESULT($atomic_ops)

AC_CHECK_LIB(socket, socket, LIBS="$LIBS -lsocket")
AC_CHECK_LIB(network, socket, LIBS="$LIBS -lnetwork")
AC_CHECK_LIB(ws2_32, main, LIBS="$LIBS -lws2_32")

AC_CHECK_FUNC(gmtime_r, [
	AC_DEFINE(HAVE_GMTIME_R, 1, [Whether we have gmtime_r])
])
AC_CHECK_FUNC(localtime_r, [
	AC_DEFINE(HAVE_LOCALTIME_R, 1, [Whether we have localtime_r])
])

AC_CHECK_FUNC(kqueue, [
	AC_DEFINE(HAVE_KQUEUE, 1, [Whether we have kqueue])
	AC_SUBST(OFSTREAMOBSERVER_KQUEUE_M, "OFStreamObserver_kqueue.m")
])
AC_CHECK_HEADER(poll.h, [
	AC_DEFINE(HAVE_POLL_H, 1, [Whether we have poll.h])
	AC_SUBST(OFSTREAMOBSERVER_POLL_M, "OFStreamObserver_poll.m")
])
AC_CHECK_HEADERS(sys/select.h, [
	AC_DEFINE(OF_HAVE_SYS_SELECT_H, 1, [Whether we have sys/select.h])
	AC_SUBST(OFSTREAMOBSERVER_SELECT_M, "OFStreamObserver_select.m")
])
case "$host_os" in
	mingw*)
		AC_SUBST(OFSTREAMOBSERVER_SELECT_M,
			"OFStreamObserver_select.m")
		;;
esac

AC_MSG_CHECKING(for getaddrinfo)
AC_TRY_COMPILE([
	#include <stddef.h>
	#ifndef _WIN32
	# include <sys/types.h>
	# include <sys/socket.h>
	# include <netdb.h>
	#else
	# define _WIN32_WINNT 0x0501
	# include <windows.h>
	# include <ws2tcpip.h>
	#endif
], [
	struct addrinfo ai;
	getaddrinfo(NULL, NULL, NULL, NULL);
], [
	AC_MSG_RESULT(yes)
	AC_DEFINE(HAVE_GETADDRINFO, 1, [Whether we have getaddrinfo])

	AS_IF([test x"$enable_threads" != x"no"], [
		AC_MSG_CHECKING(whether getaddrinfo is thread-safe)

		case "$host_os" in
			darwin[[12345]].*)
				have_threadsafe_getaddrinfo="no"
				;;
			darwin*)
				have_threadsafe_getaddrinfo="yes"
				;;
			freebsd[[1234]].* | freebsd5.[[1234]]*)
				have_threadsafe_getaddrinfo="no"
				;;
			freebsd*)
				have_threadsafe_getaddrinfo="yes"
				;;
			netbsd[[123]].*)
				have_threadsafe_getaddrinfo="no"
				;;
			netbsd*)
				have_threadsafe_getaddrinfo="yes"
				;;
			solaris*)
				have_threadsafe_getaddrinfo="yes"
				;;
			*)
				have_threadsafe_getaddrinfo="unknown"
				;;
		esac

		AS_IF([test x"$have_threadsafe_getaddrinfo" = x"unknown"], [
			AC_EGREP_CPP(yes, [
				#ifndef _WIN32
				# include <sys/types.h>
				# include <sys/socket.h>
				# include <netdb.h>
				#else
				# define _WIN32_WINNT 0x0501
				# include <windows.h>
				# include <ws2tcpip.h>
				#endif

				#ifdef h_errno
				yes
				#end
			], [
				have_threadsafe_getaddrinfo="yes"
			], [
				have_threadsafe_getaddrinfo="no"
			])
		])

		AS_IF([test x"$have_threadsafe_getaddrinfo" = x"yes"], [
			AC_DEFINE(HAVE_THREADSAFE_GETADDRINFO, 1,
				[Whether getaddrinfo is thread-safe])
		])

		AC_MSG_RESULT($have_threadsafe_getaddrinfo)
	])
], [
	AC_MSG_RESULT(no)
])

AS_IF([test x"$objc_runtime" = x"Apple runtime"], [
	AC_CHECK_HEADER(Foundation/NSObject.h, [
		AC_SUBST(FOUNDATION_COMPAT_M, "foundation-compat.m")
		AC_SUBST(BRIDGE, "bridge")

		AS_IF([test x"$enable_shared" != x"no"], [
			AC_SUBST(OBJFW_BRIDGE_SHARED_LIB,
				"${LIB_PREFIX}objfw-bridge${LIB_SUFFIX}")
		])
		AS_IF([test x"$enable_static" = x"yes" \
		    -o x"$enable_shared" = x"no"], [
			AC_SUBST(OBJFW_BRIDGE_STATIC_LIB, "libobjfw-bridge.a")
		])
	])
])

AS_IF([test x"$GOBJC" = x"yes"], [
	OBJCFLAGS="$OBJCFLAGS -Wwrite-strings -Wpointer-arith -Werror"

	AC_MSG_CHECKING(whether gcc has bug objc/27438)
	AC_TRY_COMPILE([
		@interface OFConstantString
		{
			struct objc_class *isa;
			const char *string;
			unsigned long size;
		}
		@end

		void *_OFConstantStringClassReference;
	], [
		OFConstantString *test = @"";
		(void)test; /* Get rid of unused variable warning */
	], [
		AC_MSG_RESULT(no)
	], [
		AC_MSG_RESULT([yes, adding -Wno-unused-variable])
		OBJCFLAGS="$OBJCFLAGS -Wno-unused-variable"
		AC_SUBST(NO_WARN_UNUSED, "-Wno-unused-variable")
	])

	AC_MSG_CHECKING(whether we need -Wno-strict-aliasing due to gcc bugs)
	AC_TRY_COMPILE([
		@interface Foo
		{
			struct objc_class *isa;
		}
		@end

		static struct {
			struct objc_class *isa;
		} object;
	], [
		Foo *test = (Foo*)&object;
		(void)test; /* Get rid of unused variable warning */
	], [
		AC_MSG_RESULT(no)
	], [
		AC_MSG_RESULT(yes)
		OBJCFLAGS="$OBJCFLAGS -Wno-strict-aliasing"
	])

	old_OBJCFLAGS="$OBJCFLAGS"
	OBJCFLAGS="$OBJCFLAGS -Wcast-align"
	AC_MSG_CHECKING(whether -Wcast-align is buggy)
	AC_TRY_COMPILE([
		@interface Foo
		{
			struct objc_class *isa;
		}
		@end

		@implementation Foo
		- (void)foo
		{
			struct objc_class *c = isa;
			(void)c;
		}
		@end
	], [
	], [
		AC_MSG_RESULT(no)
	], [
		AC_MSG_RESULT(yes)
		OBJCFLAGS="$old_OBJCFLAGS"
	])
])

AS_IF([test x"$cross_compiling" = x"yes"], [
	AC_SUBST(BIN_PREFIX, "$host-")

	case "$host" in
		*-*-mingw*)
			AC_CHECK_PROG(WINE, wine, wine)

			AS_IF([test x"$WINE" != x""], [
				AC_SUBST(TESTS, "tests")
				AC_SUBST(TEST_LAUNCHER, "$WINE")
			])
			;;
	esac
], [
	AC_SUBST(TESTS, "tests")
])

BUILDSYS_INIT
BUILDSYS_TOUCH_DEPS

dnl We don't call AC_PROG_CPP, but only AC_PROG_OBJCPP and set CPP to OBJCPP
dnl and add OBJCPPFLAGS to CPPFLAGS, thus we need to AC_SUBST these ourself.
AC_SUBST(CPP)
AC_SUBST(CPPFLAGS)

AC_CONFIG_FILES([
	buildsys.mk
	extra.mk
	Info.plist
	utils/objfw-config
	src/bridge/Info.plist
])
AC_CONFIG_HEADERS([config.h src/objfw-defs.h])
AC_OUTPUT

AS_IF([test x"$old_compiler" = x"yes"], [
	echo
	printf "  ** Note: Your compiler does not seem to "
	echo "accept -fobjc-runtime=objfw."
	printf "  ** To get optimal performance and be able to use all "
	echo "features, you should "
	echo "  ** install Clang >= 3.2."
	echo
])
