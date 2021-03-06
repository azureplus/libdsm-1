//
//  compat.h
//  test
//
//  Created by trekvn on 4/7/17.
//  Copyright © 2017 trekvn. All rights reserved.
//

#ifndef compat_h
#define compat_h

#include <stdio.h>
#include <stdlib.h>

#include "config.h"

#ifndef _WIN32
#   define closesocket(fd) close(fd)
#endif

#if !defined HAVE_STRLCPY && !defined HAVE_LIBBSD
size_t strlcpy(char *dst, const char *src, size_t siz);
#endif

#ifndef HAVE_CLOCKID_T
typedef int clockid_t;
#endif

#if !HAVE_DECL_CLOCK_MONOTONIC
enum {
    CLOCK_REALTIME,
    CLOCK_MONOTONIC,
    CLOCK_PROCESS_CPUTIME_ID,
    CLOCK_THREAD_CPUTIME_ID
};
#endif

#if !defined HAVE_CLOCK_GETTIME
#include <time.h>
int clock_gettime(clockid_t clk_id, struct timespec *tp);
#endif

#if !defined HAVE_STRNDUP
char *strndup(const char *str, size_t n);
#endif

#if !defined HAVE_SYS_QUEUE_H
#   include "queue.h"
#endif

#ifndef O_NONBLOCK
//#   define O_NONBLOCK 0
#endif

#if !defined(HAVE_PIPE) && defined(HAVE__PIPE)
#   define HAVE_PIPE
int pipe(int fds[2]);
#endif

#ifndef HAVE_STRUCT_TIMESPEC
struct timespec {
    time_t  tv_sec;   /* Seconds */
    long    tv_nsec;  /* Nanoseconds */
};
#endif

#endif /* compat_h */
