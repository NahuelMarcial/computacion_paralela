#pragma once

#ifndef L
#define L 384 // linear system size
#endif

#ifndef TEMP_INITIAL
#define TEMP_INITIAL 1.5 // initial temperature
#endif

#ifndef TEMP_FINAL
#define TEMP_FINAL 3.0 // final temperature
#endif

#ifndef TEMP_DELTA
#define TEMP_DELTA 0.01 // temperature step
#endif

#ifndef TRAN
#define TRAN 5 // equilibration time
#endif

#ifndef TMAX
#define TMAX 25 // measurement time
#endif

#ifndef DELTA_T
#define DELTA_T 5 // sampling period for energy and magnetization
#endif

#ifndef DATATYPE
#define DATATYPE int
#endif

#ifndef MAX_THREADS
#define MAX_THREADS 1
#endif

#ifndef PADDING
#define PADDING 1
#endif

#ifndef SCHEDULE_TYPE
#define SCHEDULE_TYPE static
#endif

#define WIDTH (L/2)
#define HEIGHT (L)
