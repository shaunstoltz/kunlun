/*-------------------------------------------------------------------------
 *
 * posix_sema.c
 *	  Implement PGSemaphores using POSIX semaphore facilities
 *
 * We prefer the unnamed style of POSIX semaphore (the kind made with
 * sem_init).  We can cope with the kind made with sem_open, however.
 *
 * In either implementation, typedef PGSemaphore is equivalent to "sem_t *".
 * With unnamed semaphores, the sem_t structs live in an array in shared
 * memory.  With named semaphores, that's not true because we cannot persuade
 * sem_open to do its allocation there.  Therefore, the named-semaphore code
 * *does not cope with EXEC_BACKEND*.  The sem_t structs will just be in the
 * postmaster's private memory, where they are successfully inherited by
 * forked backends, but they could not be accessed by exec'd backends.
 *
 *
 * Portions Copyright (c) 2019-2021 ZettaDB inc. All rights reserved.
 *
 * This source code is licensed under Apache 2.0 License,
 * combined with Common Clause Condition 1.0, as detailed in the NOTICE file.
 *
 * Portions Copyright (c) 1996-2018, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * IDENTIFICATION
 *	  src/backend/port/posix_sema.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include <fcntl.h>
#include <semaphore.h>
#include <signal.h>
#include <unistd.h>

#include "miscadmin.h"
#include "storage/ipc.h"
#include "storage/pg_sema.h"
#include "storage/shmem.h"
#include <time.h>
#include <limits.h>

/* see file header comment */
#if defined(USE_NAMED_POSIX_SEMAPHORES) && defined(EXEC_BACKEND)
#error cannot use named POSIX semaphores with EXEC_BACKEND
#endif

typedef union SemTPadded
{
	sem_t		pgsem;
	char		pad[PG_CACHE_LINE_SIZE];
} SemTPadded;

/* typedef PGSemaphore is equivalent to pointer to sem_t */
typedef struct PGSemaphoreData
{
	SemTPadded	sem_padded;
} PGSemaphoreData;

#define PG_SEM_REF(x)	(&(x)->sem_padded.pgsem)

#define IPCProtection	(0600)	/* access/modify by user only */

#ifdef USE_NAMED_POSIX_SEMAPHORES
static sem_t **mySemPointers;	/* keep track of created semaphores */
#else
static PGSemaphore sharedSemas; /* array of PGSemaphoreData in shared memory */
#endif
static int	numSems;			/* number of semas acquired so far */
static int	maxSems;			/* allocated size of above arrays */
static int	nextSemKey;			/* next name to try */


static void ReleaseSemaphores(int status, Datum arg);


#ifdef USE_NAMED_POSIX_SEMAPHORES

/*
 * PosixSemaphoreCreate
 *
 * Attempt to create a new named semaphore.
 *
 * If we fail with a failure code other than collision-with-existing-sema,
 * print out an error and abort.  Other types of errors suggest nonrecoverable
 * problems.
 */
static sem_t *
PosixSemaphoreCreate(void)
{
	int			semKey;
	char		semname[64];
	sem_t	   *mySem;

	for (;;)
	{
		semKey = nextSemKey++;

		snprintf(semname, sizeof(semname), "/pgsql-%d", semKey);

		mySem = sem_open(semname, O_CREAT | O_EXCL,
						 (mode_t) IPCProtection, (unsigned) 1);

#ifdef SEM_FAILED
		if (mySem != (sem_t *) SEM_FAILED)
			break;
#else
		if (mySem != (sem_t *) (-1))
			break;
#endif

		/* Loop if error indicates a collision */
		if (errno == EEXIST || errno == EACCES || errno == EINTR)
			continue;

		/*
		 * Else complain and abort
		 */
		elog(FATAL, "sem_open(\"%s\") failed: %m", semname);
	}

	/*
	 * Unlink the semaphore immediately, so it can't be accessed externally.
	 * This also ensures that it will go away if we crash.
	 */
	sem_unlink(semname);

	return mySem;
}
#else							/* !USE_NAMED_POSIX_SEMAPHORES */

/*
 * PosixSemaphoreCreate
 *
 * Attempt to create a new unnamed semaphore.
 */
static void
PosixSemaphoreCreate(sem_t *sem)
{
	if (sem_init(sem, 1, 1) < 0)
		elog(FATAL, "sem_init failed: %m");
}
#endif							/* USE_NAMED_POSIX_SEMAPHORES */


/*
 * PosixSemaphoreKill	- removes a semaphore
 */
static void
PosixSemaphoreKill(sem_t *sem)
{
#ifdef USE_NAMED_POSIX_SEMAPHORES
	/* Got to use sem_close for named semaphores */
	if (sem_close(sem) < 0)
		elog(LOG, "sem_close failed: %m");
#else
	/* Got to use sem_destroy for unnamed semaphores */
	if (sem_destroy(sem) < 0)
		elog(LOG, "sem_destroy failed: %m");
#endif
}


/*
 * Report amount of shared memory needed for semaphores
 */
Size
PGSemaphoreShmemSize(int maxSemas)
{
#ifdef USE_NAMED_POSIX_SEMAPHORES
	/* No shared memory needed in this case */
	return 0;
#else
	/* Need a PGSemaphoreData per semaphore */
	return mul_size(maxSemas, sizeof(PGSemaphoreData));
#endif
}

/*
 * PGReserveSemaphores --- initialize semaphore support
 *
 * This is called during postmaster start or shared memory reinitialization.
 * It should do whatever is needed to be able to support up to maxSemas
 * subsequent PGSemaphoreCreate calls.  Also, if any system resources
 * are acquired here or in PGSemaphoreCreate, register an on_shmem_exit
 * callback to release them.
 *
 * The port number is passed for possible use as a key (for Posix, we use
 * it to generate the starting semaphore name).  In a standalone backend,
 * zero will be passed.
 *
 * In the Posix implementation, we acquire semaphores on-demand; the
 * maxSemas parameter is just used to size the arrays.  For unnamed
 * semaphores, there is an array of PGSemaphoreData structs in shared memory.
 * For named semaphores, we keep a postmaster-local array of sem_t pointers,
 * which we use for releasing the semphores when done.
 * (This design minimizes the dependency of postmaster shutdown on the
 * contents of shared memory, which a failed backend might have clobbered.
 * We can't do much about the possibility of sem_destroy() crashing, but
 * we don't have to expose the counters to other processes.)
 */
void
PGReserveSemaphores(int maxSemas, int port)
{
#ifdef USE_NAMED_POSIX_SEMAPHORES
	mySemPointers = (sem_t **) malloc(maxSemas * sizeof(sem_t *));
	if (mySemPointers == NULL)
		elog(PANIC, "out of memory");
#else

	/*
	 * We must use ShmemAllocUnlocked(), since the spinlock protecting
	 * ShmemAlloc() won't be ready yet.  (This ordering is necessary when we
	 * are emulating spinlocks with semaphores.)
	 */
	sharedSemas = (PGSemaphore)
		ShmemAllocUnlocked(PGSemaphoreShmemSize(maxSemas));
#endif

	numSems = 0;
	maxSems = maxSemas;
	nextSemKey = port * 1000;

	on_shmem_exit(ReleaseSemaphores, 0);
}

/*
 * Release semaphores at shutdown or shmem reinitialization
 *
 * (called as an on_shmem_exit callback, hence funny argument list)
 */
static void
ReleaseSemaphores(int status, Datum arg)
{
	int			i;

#ifdef USE_NAMED_POSIX_SEMAPHORES
	for (i = 0; i < numSems; i++)
		PosixSemaphoreKill(mySemPointers[i]);
	free(mySemPointers);
#endif

#ifdef USE_UNNAMED_POSIX_SEMAPHORES
	for (i = 0; i < numSems; i++)
		PosixSemaphoreKill(PG_SEM_REF(sharedSemas + i));
#endif
}

/*
 * PGSemaphoreCreate
 *
 * Allocate a PGSemaphore structure with initial count 1
 */
PGSemaphore
PGSemaphoreCreate(void)
{
	PGSemaphore sema;
	sem_t	   *newsem;

	/* Can't do this in a backend, because static state is postmaster's */
	Assert(!IsUnderPostmaster);

	if (numSems >= maxSems)
		elog(PANIC, "too many semaphores created");

#ifdef USE_NAMED_POSIX_SEMAPHORES
	newsem = PosixSemaphoreCreate();
	/* Remember new sema for ReleaseSemaphores */
	mySemPointers[numSems] = newsem;
	sema = (PGSemaphore) newsem;
#else
	sema = &sharedSemas[numSems];
	newsem = PG_SEM_REF(sema);
	PosixSemaphoreCreate(newsem);
#endif

	numSems++;

	return sema;
}

/*
 * PGSemaphoreReset
 *
 * Reset a previously-initialized PGSemaphore to have count 0
 */
void
PGSemaphoreReset(PGSemaphore sema)
{
	/*
	 * There's no direct API for this in POSIX, so we have to ratchet the
	 * semaphore down to 0 with repeated trywait's.
	 */
	for (;;)
	{
		if (sem_trywait(PG_SEM_REF(sema)) < 0)
		{
			if (errno == EAGAIN || errno == EDEADLK)
				break;			/* got it down to 0 */
			if (errno == EINTR)
				continue;		/* can this happen? */
			elog(FATAL, "sem_trywait failed: %m");
		}
	}
}

/*
  dzw:
  Check for interrupts so that statement_timeout can be effective, in some
  cases we want to avoid potentially permanent waiting.
  @retval 1 if timed out; 0 if lock acqured; -1 if argument error;
*/
void
SemaFenceInitialize(SemaFence *fence)
{
	LWLockInitialize(&fence->mutex, LWLockNewTrancheId());
	fence->fence_no = 0;
}

int
PGSemaphoreTimedLockFence(PGSemaphore sema, int millisecs, SemaFence *fence)
{
	int errStatus;
	if (millisecs < 0)
		return -1;

	if (millisecs == 0)
		millisecs = 3000;

	struct timespec ts;
	/*
	  This function could be called very frequently, so we want to use
	  CLOCK_REALTIME_COARSE instead of CLOCK_REALTIME to avoid too much
	  performance overhead.
	*/
	if (clock_gettime(CLOCK_REALTIME_COARSE, &ts) != 0)
	{
		if (errno != EINVAL)
		{
			elog(FATAL, "clock_gettime failed: %m");
		}
		/*
		  COARSE not supported, use an even less precise version.
		*/
		ts.tv_sec = time(0);
		ts.tv_nsec = 0;
	}
	ts.tv_sec += millisecs / 1000;
	ts.tv_nsec += (millisecs % 1000 * 1000000);
	if (ts.tv_nsec < 0)
	{
		// if overflows, wrap around and bump sec.
		ts.tv_nsec &= LONG_MAX;
		ts.tv_sec += 1;
	}

	/* See notes in sysv_sema.c's implementation of PGSemaphoreLock. */
	do
	{
		errStatus = sem_timedwait(PG_SEM_REF(sema), &ts);
	} while (errStatus < 0 && errno == EINTR);

	if (errStatus < 0 && (errno != EAGAIN && errno != ETIMEDOUT))
		elog(FATAL, "sem_timedwait failed: %m");

	/* Block semaphore with same fence */
	{
		LWLockAcquire(&fence->mutex, LW_EXCLUSIVE);
		fence->fence_no++;
		LWLockRelease(&fence->mutex);
	}

	/* Timeout, consume late semaphore */
	if (errStatus != 0)
	{
		(void)PGSemaphoreTryLock(sema);
		return 1;
	}

	return 0;
}

void
PGSemaphoreUnlockFence(PGSemaphore sema, SemaFence *fence, long fenceNo)
{
	if (fence->fence_no == fenceNo)
	{
		LWLockAcquire(&fence->mutex, LW_EXCLUSIVE);
		if (fence->fence_no == fenceNo)
			PGSemaphoreUnlock(sema);
		LWLockRelease(&fence->mutex);
	}
}

/*
 * PGSemaphoreLock
 *
 * Lock a semaphore (decrement count), blocking if count would be < 0
 */
void
PGSemaphoreLock(PGSemaphore sema)
{
	int			errStatus;

	/* See notes in sysv_sema.c's implementation of PGSemaphoreLock. */
	do
	{
		errStatus = sem_wait(PG_SEM_REF(sema));
	} while (errStatus < 0 && errno == EINTR);

	if (errStatus < 0)
		elog(FATAL, "sem_wait failed: %m");
}

/*
 * PGSemaphoreUnlock
 *
 * Unlock a semaphore (increment count)
 */
void
PGSemaphoreUnlock(PGSemaphore sema)
{
	int			errStatus;

	/*
	 * Note: if errStatus is -1 and errno == EINTR then it means we returned
	 * from the operation prematurely because we were sent a signal.  So we
	 * try and unlock the semaphore again. Not clear this can really happen,
	 * but might as well cope.
	 */
	do
	{
		errStatus = sem_post(PG_SEM_REF(sema));
	} while (errStatus < 0 && errno == EINTR);

	if (errStatus < 0)
		elog(FATAL, "sem_post failed: %m");
}

/*
 * PGSemaphoreTryLock
 *
 * Lock a semaphore only if able to do so without blocking
 */
bool
PGSemaphoreTryLock(PGSemaphore sema)
{
	int			errStatus;

	/*
	 * Note: if errStatus is -1 and errno == EINTR then it means we returned
	 * from the operation prematurely because we were sent a signal.  So we
	 * try and lock the semaphore again.
	 */
	do
	{
		errStatus = sem_trywait(PG_SEM_REF(sema));
	} while (errStatus < 0 && errno == EINTR);

	if (errStatus < 0)
	{
		if (errno == EAGAIN || errno == EDEADLK)
			return false;		/* failed to lock it */
		/* Otherwise we got trouble */
		elog(FATAL, "sem_trywait failed: %m");
	}

	return true;
}
