! --------------------------------------------------------------------
! Copyright (C) 1991 - 2020 - EDF R&D - www.code-aster.org
! This file is part of code_aster.
!
! code_aster is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! code_aster is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with code_aster.  If not, see <http://www.gnu.org/licenses/>.
! --------------------------------------------------------------------
!
subroutine sshEpslSB9(epsg, epsl, gn, lamb, logl, iret)
!
implicit none
!
#include "asterc/r8miem.h"
#include "asterfort/diagp3.h"
#include "asterfort/tnsvec.h"
#include "asterfort/lcdetf.h"
#include "asterc/r8prem.h"
!
real(kind=8), intent(in) :: epsg(6)
real(kind=8), intent(out) :: epsl(6)
real(kind=8), intent(out) :: gn(3, 3), lamb(3), logl(3)
integer, intent(out) :: iret
!
! --------------------------------------------------------------------------------------------------
!
! Solid-shell element - SB9
!
! Compute logarithmic strains at current Gauss point
!
! --------------------------------------------------------------------------------------------------
!
! In  epsg             : Green-Lagrange strains
! Out epsl             : logarithmic strains
! Out gn               : eigen vectors for F tensor
! Out lamb             : eigen values for F tensor
! Out logl             : log(lamb)
! Out iret             : return code for error
!                         0=OK, 1=vp(Ft.F) trop petites (compression infinie)
!
! --------------------------------------------------------------------------------------------------
!
    integer, parameter :: nbvec = 3
    real(kind=8) :: tr(6), epsl33(3, 3)
    integer :: i, j, k
!
! --------------------------------------------------------------------------------------------------
!
    iret   = 0
    epsl   = 0.d0
    gn     = 0.d0
    lamb   = 0.d0
    logl   = 0.d0
!
! - Vector form of strain tensor C=F'F=2E+I
!
    tr(1) = 2.d0*epsg(1)+1.d0
    tr(2) = epsg(4)
    tr(3) = epsg(5)
    tr(4) = 2.d0*epsg(2)+1.d0
    tr(5) = epsg(6)
    tr(6) = 2.d0*epsg(3)+1.d0
!
! - Eigen values/vectors of strain tensor
!
    call diagp3(tr, gn, lamb)
!
! - Compute logarithms
!
    do i = 1, nbvec
        if (lamb(i) .le. r8miem()) then
            iret = 1
            goto 999
        endif
        logl(i) = log(lamb(i))*0.5d0
    end do
!
! - Compute logarithmic strains
!
    epsl33 = 0.d0
    epsl   = 0.d0
    do i = 1, 3
        do j = 1, 3
            do k = 1, nbvec
                epsl33(i,j) = epsl33(i,j) + logl(k)*gn(i,k)*gn(j,k)
            end do
        end do
    end do
!
! - Voigt form of strain tensor
!
    call tnsvec(3, 3, epsl33, epsl, sqrt(2.d0))
!
999 continue
end subroutine
