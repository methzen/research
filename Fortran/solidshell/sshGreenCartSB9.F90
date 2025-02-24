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
! but WITHOUT ANY WARRANTY without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with code_aster.  If not, see <http://www.gnu.org/licenses/>.
! --------------------------------------------------------------------
!
subroutine sshGreenCartSB9(nb_node , nb_dof,&
                           geomInit, disp  ,&
                           EH1     , EH2   ,&
                           EH23    , EH13)
!
implicit none
!
#include "asterfort/assert.h"
#include "asterf_types.h"
#include "asterfort/sshTMatrDecoSB9.h"
#include "asterfort/sshGreenCovaSB9.h"
#include "asterfort/sshTMatrSB9.h"

!
integer, intent(in) :: nb_node, nb_dof
real(kind=8), intent(in) :: geomInit(3*nb_node), disp(nb_dof)
real(kind=8), intent(out) :: EH1(6), EH2(6), EH23(6), EH13(6)
!
! --------------------------------------------------------------------------------------------------
!
! Solid-shell element - SB9
!
! Compute Green-Lagrange strains in cartesian frame
!
! --------------------------------------------------------------------------------------------------
!
! In  nb_node          : number of nodes of element without pinch node(s)
! In  nb_dof           : number of dof
! In  geomInit         : initial coordinates of element
! In  disp             : displacements of element
! Out EH1              : Green-Lagrange strain for stabilization - Component 1
! Out EH2              : Green-Lagrange strain for stabilization - Component 2
! Out EH13             : Green-Lagrange strain for stabilization - Component 13
! Out EH23             : Green-Lagrange strain for stabilization - Component 23
!
! --------------------------------------------------------------------------------------------------
!
    real(kind=8) :: Ec0(6), EcZETA(6), EcXI(6)
    real(kind=8) :: EcETA(6), EcETAZETA(6), EcXIZETA(6)
    real(kind=8) :: TXI(6,6), TETA(6,6), TZETA(6,6), T0(6,6)
!
! --------------------------------------------------------------------------------------------------
!
    ASSERT(nb_node .eq. 8)
    ASSERT(nb_dof .eq. 25)
    EH1  = 0.d0
    EH2  = 0.d0
    EH23 = 0.d0
    EH13 = 0.d0
!
! - Compute Green-Lagrange strains in covariant frame
!
    call sshGreenCovaSB9(nb_node , nb_dof,&
                         geomInit, disp  ,&
                         Ec0_ = Ec0 , EcZETA_ = EcZETA,&
                         EcXI_= EcXI, EcETA_  = EcETA ,&
                         EcETAZETA_ = EcETAZETA,&
                         EcXIZETA_  = EcXIZETA)
!
! - Compute the decomposition of the inverse Jacobian matrix
!
    call sshTMatrDecoSB9(nb_node, geomInit, TXI, TETA, TZETA)
!
! - Compute matrix relating the convective and Cartesian frame (linear part)
!
    call sshTMatrSB9(nb_node, geomInit, (/0.d0,0.d0,0.d0/), T0)
!
! - Compute Green-Lagrange strains in cartesian frame
!
    EH1  = matmul(T0,EcXI) + matmul(TXI,Ec0)
    EH2  = matmul(T0,EcETA) + matmul(TETA,Ec0)
    EH23 = matmul(T0,EcETAZETA) + matmul(TETA,EcZETA) + matmul(TZETA,EcETA)
    EH13 = matmul(T0,EcXIZETA) + matmul(TXI,EcZETA) + matmul(TZETA,EcXI)
!
end subroutine
