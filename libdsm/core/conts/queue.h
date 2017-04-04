//
//  queue.h
//  libdsm
//
//  Created by trekvn on 4/3/17.
//  Copyright © 2017 trekvn. All rights reserved.
//
#define _TAILQ_HEAD(name, type, qual) \
struct name { \
    qual type *tqh_first;           /*!-->first element */\
    qual type *qual *tqh_last       /*!-->addr of last element */\
}

#define TAILQ_HEAD(name, type)	_TAILQ_HEAD(name, struct type,)

#define	TAILQ_HEAD_INITIALIZER(head) {\
    TAILQ_END(head), &(head).tqh_first \
}

#define	_TAILQ_ENTRY(type, qual)					\
struct {								\
    qual type *tqe_next;		/*!--> next element */		\
    qual type *qual *tqe_prev;	/*!--> address of previous next element */\
}

#define TAILQ_ENTRY(type)	_TAILQ_ENTRY(struct type,)

/*!
 * Tail queue access methods.
 */
#define	TAILQ_FIRST(head)		((head)->tqh_first)
#define	TAILQ_END(head)			(NULL)
#define	TAILQ_NEXT(elm, field)		((elm)->field.tqe_next)
#define	TAILQ_LAST(head, headname) \
(*(((struct headname *)(void *)((head)->tqh_last))->tqh_last))
#define	TAILQ_PREV(elm, headname, field) \
(*(((struct headname *)(void *)((elm)->field.tqe_prev))->tqh_last))
#define	TAILQ_EMPTY(head)		(TAILQ_FIRST(head) == TAILQ_END(head))


#define	TAILQ_FOREACH(var, head, field)					\
for ((var) = ((head)->tqh_first);				\
(var) != TAILQ_END(head);					\
(var) = ((var)->field.tqe_next))

#define	TAILQ_FOREACH_SAFE(var, head, field, next)			\
for ((var) = ((head)->tqh_first);				\
(var) != TAILQ_END(head) &&					\
((next) = TAILQ_NEXT(var, field), 1); (var) = (next))

#define	TAILQ_FOREACH_REVERSE(var, head, headname, field)		\
for ((var) = TAILQ_LAST((head), headname);			\
(var) != TAILQ_END(head);					\
(var) = TAILQ_PREV((var), headname, field))

#define	TAILQ_FOREACH_REVERSE_SAFE(var, head, headname, field, prev)	\
for ((var) = TAILQ_LAST((head), headname);			\
(var) != TAILQ_END(head) && 				\
((prev) = TAILQ_PREV((var), headname, field), 1); (var) = (prev))

/*
 * Tail queue functions.
 */
#if defined(QUEUEDEBUG)
#define	QUEUEDEBUG_TAILQ_INSERT_HEAD(head, elm, field)			\
if ((head)->tqh_first &&					\
(head)->tqh_first->field.tqe_prev != &(head)->tqh_first)	\
QUEUEDEBUG_ABORT("TAILQ_INSERT_HEAD %p %s:%d", (head),	\
__FILE__, __LINE__);
#define	QUEUEDEBUG_TAILQ_INSERT_TAIL(head, elm, field)			\
if (*(head)->tqh_last != NULL)					\
QUEUEDEBUG_ABORT("TAILQ_INSERT_TAIL %p %s:%d", (head),	\
__FILE__, __LINE__);
#define	QUEUEDEBUG_TAILQ_OP(elm, field)					\
if ((elm)->field.tqe_next &&					\
(elm)->field.tqe_next->field.tqe_prev !=			\
&(elm)->field.tqe_next)					\
QUEUEDEBUG_ABORT("TAILQ_* forw %p %s:%d", (elm),	\
__FILE__, __LINE__);				\
if (*(elm)->field.tqe_prev != (elm))				\
QUEUEDEBUG_ABORT("TAILQ_* back %p %s:%d", (elm),	\
__FILE__, __LINE__);
#define	QUEUEDEBUG_TAILQ_PREREMOVE(head, elm, field)			\
if ((elm)->field.tqe_next == NULL &&				\
(head)->tqh_last != &(elm)->field.tqe_next)			\
QUEUEDEBUG_ABORT("TAILQ_PREREMOVE head %p elm %p %s:%d",\
(head), (elm), __FILE__, __LINE__);
#define	QUEUEDEBUG_TAILQ_POSTREMOVE(elm, field)				\
(elm)->field.tqe_next = (void *)1L;				\
(elm)->field.tqe_prev = (void *)1L;
#else
#define	QUEUEDEBUG_TAILQ_INSERT_HEAD(head, elm, field)
#define	QUEUEDEBUG_TAILQ_INSERT_TAIL(head, elm, field)
#define	QUEUEDEBUG_TAILQ_OP(elm, field)
#define	QUEUEDEBUG_TAILQ_PREREMOVE(head, elm, field)
#define	QUEUEDEBUG_TAILQ_POSTREMOVE(elm, field)
#endif

#define	TAILQ_INIT(head) do {						\
(head)->tqh_first = TAILQ_END(head);				\
(head)->tqh_last = &(head)->tqh_first;				\
} while (/*CONSTCOND*/0)

#define	TAILQ_INSERT_HEAD(head, elm, field) do {			\
QUEUEDEBUG_TAILQ_INSERT_HEAD((head), (elm), field)		\
if (((elm)->field.tqe_next = (head)->tqh_first) != TAILQ_END(head))\
(head)->tqh_first->field.tqe_prev =			\
&(elm)->field.tqe_next;				\
else								\
(head)->tqh_last = &(elm)->field.tqe_next;		\
(head)->tqh_first = (elm);					\
(elm)->field.tqe_prev = &(head)->tqh_first;			\
} while (/*CONSTCOND*/0)

#define	TAILQ_INSERT_TAIL(head, elm, field) do {			\
QUEUEDEBUG_TAILQ_INSERT_TAIL((head), (elm), field)		\
(elm)->field.tqe_next = TAILQ_END(head);			\
(elm)->field.tqe_prev = (head)->tqh_last;			\
*(head)->tqh_last = (elm);					\
(head)->tqh_last = &(elm)->field.tqe_next;			\
} while (/*CONSTCOND*/0)

#define	TAILQ_INSERT_AFTER(head, listelm, elm, field) do {		\
QUEUEDEBUG_TAILQ_OP((listelm), field)				\
if (((elm)->field.tqe_next = (listelm)->field.tqe_next) != 	\
TAILQ_END(head))						\
(elm)->field.tqe_next->field.tqe_prev = 		\
&(elm)->field.tqe_next;				\
else								\
(head)->tqh_last = &(elm)->field.tqe_next;		\
(listelm)->field.tqe_next = (elm);				\
(elm)->field.tqe_prev = &(listelm)->field.tqe_next;		\
} while (/*CONSTCOND*/0)

#define	TAILQ_INSERT_BEFORE(listelm, elm, field) do {			\
QUEUEDEBUG_TAILQ_OP((listelm), field)				\
(elm)->field.tqe_prev = (listelm)->field.tqe_prev;		\
(elm)->field.tqe_next = (listelm);				\
*(listelm)->field.tqe_prev = (elm);				\
(listelm)->field.tqe_prev = &(elm)->field.tqe_next;		\
} while (/*CONSTCOND*/0)

#define	TAILQ_REMOVE(head, elm, field) do {				\
QUEUEDEBUG_TAILQ_PREREMOVE((head), (elm), field)		\
QUEUEDEBUG_TAILQ_OP((elm), field)				\
if (((elm)->field.tqe_next) != TAILQ_END(head))			\
(elm)->field.tqe_next->field.tqe_prev = 		\
(elm)->field.tqe_prev;				\
else								\
(head)->tqh_last = (elm)->field.tqe_prev;		\
*(elm)->field.tqe_prev = (elm)->field.tqe_next;			\
QUEUEDEBUG_TAILQ_POSTREMOVE((elm), field);			\
} while (/*CONSTCOND*/0)

#define TAILQ_REPLACE(head, elm, elm2, field) do {			\
if (((elm2)->field.tqe_next = (elm)->field.tqe_next) != 	\
TAILQ_END(head))   						\
(elm2)->field.tqe_next->field.tqe_prev =		\
&(elm2)->field.tqe_next;				\
else								\
(head)->tqh_last = &(elm2)->field.tqe_next;		\
(elm2)->field.tqe_prev = (elm)->field.tqe_prev;			\
*(elm2)->field.tqe_prev = (elm2);				\
QUEUEDEBUG_TAILQ_POSTREMOVE((elm), field);			\
} while (/*CONSTCOND*/0)

#define	TAILQ_CONCAT(head1, head2, field) do {				\
if (!TAILQ_EMPTY(head2)) {					\
*(head1)->tqh_last = (head2)->tqh_first;		\
(head2)->tqh_first->field.tqe_prev = (head1)->tqh_last;	\
(head1)->tqh_last = (head2)->tqh_last;			\
TAILQ_INIT((head2));					\
}								\
} while (/*CONSTCOND*/0)