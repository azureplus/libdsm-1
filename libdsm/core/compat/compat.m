//
//  compat.m
//  libdsm
//
//  Created by trekvn on 4/3/17.
//  Copyright © 2017 trekvn. All rights reserved.
//

#import "compat.h"

#if !defined(HAVE_PIPE) && defined(HAVE__PIPE)
#include <fcntl.h>

int pipe(int fds[2]) {
    return _pipe(fds, 32768, O_NOINHERIT | O_BINARY);
}
#endif
