#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include <check.h>

#include "matrices.h"
#include "blasglue.h"

/* Simple operations on sqmatrices.  Also, some not-so-simple operations,
   like inversion and eigenvalue decomposition. */

/* A = B */
void sqmatrix_copy(sqmatrix A, sqmatrix B)
{
     CHECK(A.p == B.p, "arrays not conformant");

     blasglue_copy(A.p * A.p, B.data, 1, A.data, 1);
}

/* trace(U) */
scalar sqmatrix_trace(sqmatrix U)
{
     int i;
     scalar trace = SCALAR_INIT_ZERO;

     for (i = 0; i < U.p; ++i)
	  ACCUMULATE_SUM(trace, U.data[i*U.p + i]);

     return trace;
}

/* compute trace(adjoint(A) * B) */
scalar sqmatrix_traceAtB(sqmatrix A, sqmatrix B)
{
     scalar trace;

     CHECK(A.p == B.p, "matrices not conformant");

     trace = blasglue_dotc(A.p * A.p, A.data, 1, B.data, 1);

     return trace;
}

/* A = B * C.  If bdagger != 0, then adjoint(B) is used; similarly for C. 
   A must be distinct from B and C.  */
void sqmatrix_AeBC(sqmatrix A, sqmatrix B, short bdagger,
		   sqmatrix C, short cdagger)
{
     CHECK(A.p == B.p && A.p == C.p, "matrices not conformant");

     blasglue_gemm(bdagger ? 'C' : 'N', cdagger ? 'C' : 'N', A.p, A.p, A.p,
                   1.0, B.data, B.p, C.data, C.p, 0.0, A.data, A.p);
}

/* A += a B */
void sqmatrix_ApaB(sqmatrix A, real a, sqmatrix B)
{
     CHECK(A.p == B.p, "matrices not conformant");

     blasglue_axpy(A.p * A.p, a, B.data, 1, A.data, 1);
}

/* U <- Cholesky factorization of U, which can
   subsequently be used to multiply other matrices by 1/U.

   If compute_Uinv is true, then U <- 1/U.

   U must be Hermitian and positive-definite (e.g. U = Yt*Y). */
void sqmatrix_invert(sqmatrix U, short compute_Uinv)
{
     /* factorize U: */
     lapackglue_potrf('U', U.p, U.data, U.p);

     if (compute_Uinv) {
          int i, j;

	  /* Compute 1/U (upper half only) */
	  lapackglue_potri('U', U.p, U.data, U.p);

	  /* Now, copy the conjugate of the upper half
	     onto the lower half of U */
          for (i = 0; i < U.p; ++i)
               for (j = i + 1; j < U.p; ++j) {
                    ASSIGN_CONJ(U.data[j * U.p + i], U.data[i * U.p + j]);
               }
     }
}

/* U <- eigenvectors of U.  U must be Hermitian. eigenvals <- eigenvalues.
   W is a work array.  The columns of adjoint(U') are the eigenvectors, so that
   U == adjoint(U') D U', with D = diag(eigenvals). 

   The eigenvalues are returned in ascending order. */
void sqmatrix_eigensolve(sqmatrix U, real *eigenvals, sqmatrix W)
{
     real *work;

     work = (real*) malloc(sizeof(real) * (3*U.p - 2));
     CHECK(work, "out of memory");

     if (W.p * W.p >= 3 * U.p - 1)
       lapackglue_heev('V', 'U', U.p, U.data, U.p, eigenvals,
		       W.data, W.p * W.p, work);
     else {
       scalar *morework = (scalar*) malloc(sizeof(scalar) * (3 * U.p - 1));
       CHECK(morework, "out of memory");
       lapackglue_heev('V', 'U', U.p, U.data, U.p, eigenvals,
                       morework, 3 * U.p - 1, work);
       free(morework);
     }

     free(work);
}

/* Compute Usqrt <- sqrt(U), where U must be Hermitian positive-definite. 
   W is a work array, and must be the same size as U.  Both U and
   W are overwritten. */
void sqmatrix_sqrt(sqmatrix Usqrt, sqmatrix U, sqmatrix W)
{
     real *eigenvals;

     CHECK(Usqrt.p == U.p && U.p == W.p, "matrices not conformant");

     eigenvals = (real*) malloc(sizeof(real) * U.p);
     CHECK(eigenvals, "out of memory");

     sqmatrix_eigensolve(U, eigenvals, W);

     {
	  int i;
	  
	  /* Compute W = diag(sqrt(eigenvals)) * U; i.e. the rows of W
	     become the rows of U times sqrt(corresponding eigenvalue) */
	  for (i = 0; i < U.p; ++i) {
	       CHECK(eigenvals[i] > 0, "non-positive eigenvalue");
	       
	       blasglue_copy(U.p, U.data + i*U.p, 1, W.data + i*U.p, 1);
	       blasglue_scal(U.p, sqrt(eigenvals[i]), W.data + i*U.p, 1);
	  }
     }

     free(eigenvals);

     /* compute Usqrt = Ut * W */
     sqmatrix_AeBC(Usqrt, U, 1, W, 0);
}