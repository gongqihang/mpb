#include <stdio.h>
#include <stdlib.h>

#include <mpiglue.h>

#include <check.h>

#include "matrices.h"
#include "blasglue.h"

/* Operations on evectmatrix blocks:
       X + a Y, X * S, X + a Y * S, Xt * X, Xt * Y, trace(Xt * Y), etc.
   (X, Y: evectmatrix, S: sqmatrix) */

/* X = Y */
void evectmatrix_copy(evectmatrix X, evectmatrix Y)
{
     CHECK(X.n == Y.n && X.p == Y.p, "arrays not conformant");

     blasglue_copy(X.n * X.p, Y.data, 1, X.data, 1);
}

/* compute X = a*X + b*Y; X and Y may be equal. */
void evectmatrix_aXpbY(real a, evectmatrix X, real b, evectmatrix Y)
{
     CHECK(X.n == Y.n && X.p == Y.p, "arrays not conformant");
     
     if (a != 1.0)
	  blasglue_scal(X.n * X.p, a, X.data, 1);

     blasglue_axpy(X.n * X.p, b, Y.data, 1, X.data, 1);
}

/* compute X = YS.  If sdagger != 0, then adjoint(S) is used instead.
   For Hermitian S, sdagger = 1 is probably preferred, since this
   should lead to greater locality in the matrix multiply. */
void evectmatrix_XeYS(evectmatrix X, evectmatrix Y, sqmatrix S, short sdagger)
{
     CHECK(X.p == Y.p && X.n == Y.n && X.p == S.p, "arrays not conformant");

     blasglue_gemm('N', sdagger ? 'C' : 'N', X.n, X.p, X.p,
		   1.0, Y.data, Y.p, S.data, S.p, 0.0, X.data, X.p);
}

/* compute X += a Y * S. */
void evectmatrix_XpaYS(evectmatrix X, real a, evectmatrix Y, sqmatrix S)
{
     CHECK(X.n == Y.n && X.p == Y.p && X.p == S.p, "arrays not conformant");

     blasglue_gemm('N', 'N', X.n, X.p, X.p,
		   a, Y.data, Y.p, S.data, S.p, 1.0, X.data, X.p);
}

/* compute U = adjoint(X) * X */
void evectmatrix_XtX(sqmatrix U, evectmatrix X)
{
     CHECK(X.p == U.p, "matrices not conformant");
     
/*
     blasglue_gemm('C', 'N', X.p, X.p, X.n,
		   1.0, X.data, X.p, X.data, X.p, 0.0, U.data, U.p);
*/

     /* take advantage of the fact that U is Hermitian and only write
	out the upper triangle of the matrix */
     blasglue_herk('U', 'C', X.p, X.n, 1.0, X.data, X.p, 0.0, U.data, U.p);

     /* Now, copy the conjugate of the upper half onto the lower half of U */
     {
	  int i, j;

	  for (i = 0; i < U.p; ++i)
	       for (j = i + 1; j < U.p; ++j) {
		    ASSIGN_CONJ(U.data[j * U.p + i], U.data[i * U.p + j]);
	       }
     }

     MPI_Allreduce(U.data, U.data, U.p * U.p * SCALAR_NUMVALS,
		   SCALAR_MPI_TYPE, MPI_SUM, MPI_COMM_WORLD);
}

/* compute U = adjoint(X) * Y */
void evectmatrix_XtY(sqmatrix U, evectmatrix X, evectmatrix Y)
{
     CHECK(X.p == Y.p && X.n == Y.n && X.p == U.p, "matrices not conformant");
     
     blasglue_gemm('C', 'N', X.p, X.p, X.n,
		   1.0, X.data, X.p, Y.data, Y.p, 0.0, U.data, U.p);

     MPI_Allreduce(U.data, U.data, U.p * U.p * SCALAR_NUMVALS,
		   SCALAR_MPI_TYPE, MPI_SUM, MPI_COMM_WORLD);
}

/* compute trace(adjoint(X) * Y) */
scalar evectmatrix_traceXtY(evectmatrix X, evectmatrix Y)
{
     scalar trace;

     CHECK(X.p == Y.p && X.n == Y.n, "matrices not conformant");
     
     trace = blasglue_dotc(X.n * X.p, X.data, 1, Y.data, 1);

     MPI_Allreduce(&trace, &trace, SCALAR_NUMVALS, SCALAR_MPI_TYPE,
		   MPI_SUM, MPI_COMM_WORLD);

     return trace;
}