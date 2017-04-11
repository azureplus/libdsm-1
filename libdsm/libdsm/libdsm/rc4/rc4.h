//
//  rc4.h
//  test
//
//  Created by trekvn on 4/10/17.
//  Copyright © 2017 trekvn. All rights reserved.
//

#ifndef rc4_h
#define rc4_h

#include <stdio.h>

#include <stdint.h>

struct rc4_state
{
    uint8_t  perm[256];
    uint8_t  index1;
    uint8_t  index2;
};

extern void rc4_init(struct rc4_state *state, const uint8_t *key, int keylen);
extern void rc4_crypt(struct rc4_state *state,
                      const uint8_t *inbuf, uint8_t *outbuf, int buflen);

#endif /* rc4_h */
