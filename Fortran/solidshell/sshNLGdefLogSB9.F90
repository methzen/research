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
! aslint: disable=W1504, W1306
!
subroutine sshNLGdefLogSB9(typmod   , option  , fami    ,&
                           npg      , nb_node , nb_dof  , lgpg   ,&
                           jv_poids , jv_coopg, jv_vf   , jv_dfde,&
                           imate     ,&
                           angl_naut, compor  , carcri  ,&
                           timePrev , timeCurr,&
                           geomInit , dispPrev, dispIncr,&
                           sigm     , vim      ,&
                           sigp     , vip      ,&
                           matuu    , vectu    ,&
                           codret)
!
use Behaviour_type
use Behaviour_module
!
implicit none
!
#include "asterf_types.h"
#include "jeveux.h"
#include "asterfort/Behaviour_type.h"
#include "asterfort/assert.h"
#include "asterfort/codere.h"
#include "asterfort/nmcomp.h"
#include "asterfort/sshNLPreLogSB9.h"
#include "asterfort/sshNLPosLogSB9.h"
#include "asterfort/sshGradMatrCartSB9.h"
#include "asterfort/sshGradMatrSB9.h"
#include "asterfort/sshEpsgSB9.h"
#include "asterfort/nbsigm.h"
#include "asterfort/sshNLStabForcSB9.h"
#include "asterfort/sshNLVect.h"
#include "asterfort/sshNLMatr.h"
#include "asterfort/sshRigiGeomPtSB9.h"
#include "asterfort/sshTMatrDecoSB9.h"
#include "asterfort/sshTMatrSB9.h"
#include "asterfort/sshNLStabSB9.h"
#include "asterfort/utmess.h"
!
integer, intent(in) :: npg, imate, lgpg, nb_node, nb_dof
integer, intent(in) :: jv_poids, jv_coopg, jv_vf, jv_dfde
character(len=*), intent(in) :: fami
character(len=8), intent(in) :: typmod(*)
character(len=16), intent(in) :: option, compor(*)
real(kind=8), intent(in) :: carcri(*)
real(kind=8), intent(in) :: timePrev, timeCurr
real(kind=8), intent(in) :: geomInit(3*nb_node), dispPrev(nb_dof), dispIncr(nb_dof)
real(kind=8), intent(in) :: angl_naut(*)
real(kind=8), intent(in) :: sigm(6,npg), vim(lgpg,npg)
real(kind=8), intent(out) :: sigp(6,npg), vip(lgpg,npg)
real(kind=8), intent(out) :: matuu(*), vectu(*)
integer, intent(out) :: codret
!
! --------------------------------------------------------------------------------------------------
!
! Solid-shell element - SB9
!
! Compute non-linear options for finite strains with GDEF_LOG model
!
! --------------------------------------------------------------------------------------------------
!
! In  typmod           : type of modelization
! In  option           : option to compute
! In  fami             : Gauss family for integration point rule
! In  npg              : number of Gauss points
! In  nb_node          : number of nodes of element without pinch node(s)
! In  nb_dof           : number of dof
! In  lgpg             : length of internal state variable vector
! In  jv_poids         : JEVEUX adress to weight of Gauss points
! In  jv_coopg         : JEVEUX adress to coordinates of Gauss points
! In  geomInit         : initial coordinates of element
! In  imate            : coded material address
! In  angl_naut        : nautical angles for anistropic material
! In  compor           : behaviour
! In  carcri           : parameters for behaviour
! Out vectu            : internal force vector
! Out matuu            : tangent matrix
! Out codret           : return code for error
!
! --------------------------------------------------------------------------------------------------
!
    type(Behaviour_Integ) :: BEHinteg
    integer :: i_tens, kpg, nbsig
    integer :: cod(npg)
    aster_logical :: lLarge, lVect, lMatr, lMatrPred, lSigm
    real(kind=8) :: poids, zeta, det
    real(kind=8), dimension(6,6) :: dsidep, dtde
    real(kind=8) :: dispCurr(25)
    real(kind=8) :: epslPrev(6), epslIncr(6)
    real(kind=8) :: epsgCurr(6), epsgPrev(6)
    real(kind=8) :: tPrev(6), tCurr(6)
    real(kind=8) :: gn(3, 3), lamb(3), logl(3)
    real(kind=8) :: pk2Curr(6), sigg(6)
    real(kind=8), parameter :: rac2 = sqrt(2.d0)
    real(kind=8) :: B0(6,24), B9(6), B(6, nb_dof)
    real(kind=8) :: BXI(6,24), BETA(6,24), BZETA(6,24)
    real(kind=8) :: BXIZETA(6,24), BETAZETA(6,24), BZETAZETA(6,24)
    real(kind=8) :: u1eff, ueff
    real(kind=8) :: TZETA(6,6), T(6,6)
    real(kind=8) :: kGeom(25, 25)
    integer, parameter :: ndim = 3
!
! --------------------------------------------------------------------------------------------------
!
    codret = 0
    nbsig  = nbsigm()
    lLarge = ASTER_TRUE
!
    ASSERT(nb_node .eq. 8)
    ASSERT(nb_dof .eq. 25)
    ASSERT(nbsig .eq. 6)
!
! - Initialisation of behaviour datastructure
!
    call behaviourInit(BEHinteg)
!
! - Prepare external state variables
!
    call behaviourPrepESVAElem(carcri  , typmod  ,&
                               nb_node , npg     , ndim ,&
                               jv_poids, jv_vf   , jv_dfde,&
                               geomInit, BEHinteg)
! - Update displacements
!
    dispCurr  = dispPrev + dispIncr
!
! - Quantities to compute
!
    lVect     = option(1:9) .eq. 'FULL_MECA' .or. option(1:9) .eq. 'RAPH_MECA'
    lMatr     = option(1:10) .eq. 'RIGI_MECA_' .or. option(1: 9) .eq. 'FULL_MECA'
    lMatrPred = option(1:9) .eq. 'RIGI_MECA'
    lSigm     = option(1:9) .eq. 'FULL_MECA' .or. option(1:9) .eq. 'RAPH_MECA'
!
! - Compute the deformation gradient in cartesian base
!
    if (lMatrPred) then
        call sshGradMatrCartSB9(nb_node  , geomInit,&
                                nb_dof   , dispPrev,&
                                B0       , BZETA   , BZETAZETA,&
                                BXI      , BETA    , &
                                BXIZETA  , BETAZETA, &
                                det)
    else
        call sshGradMatrCartSB9(nb_node  , geomInit,&
                                nb_dof   , dispCurr,&
                                B0       , BZETA   , BZETAZETA,&
                                BXI      , BETA    , &
                                BXIZETA  , BETAZETA, &
                                det)
    endif
!
! - Get absolute
!
    det = abs(det)
!
! - Compute the decomposition of the inverse Jacobian matrix
!
    call sshTMatrDecoSB9(nb_node, geomInit, TZETA_ = TZETA)
!
! - Compute T matrix (matrix relating the covariant and cartesian frames) at center of element
!
    call sshTMatrSB9(nb_node, geomInit, (/0.d0,0.d0,0.d0/), T)
!
! - Loop on Gauss points
!
    ueff = 0.d0
    cod  = 0
    do kpg = 1, npg
        zeta  = zr(jv_coopg-1+3*kpg)
        poids = zr(jv_poids+kpg-1)
! ----- Compute B matrix at current Gauss point
        call sshGradMatrSB9(nb_node, nb_dof  ,&
                            zeta   , geomInit,&
                            B0     , BZETA   , BZETAZETA,&
                            B      , B9)
! ----- Compute strains at beginning of time step
        call sshEpsgSB9(nb_node, nb_dof, geomInit, dispPrev, zeta, epsgPrev)
! ----- Compute strains at end of time step
        call sshEpsgSB9(nb_node, nb_dof, geomInit, dispCurr, zeta, epsgCurr)
! ----- Add EAS effect
        epsgPrev    = epsgPrev + B9*dispPrev(25)
        epsgCurr    = epsgCurr + B9*dispCurr(25)
! ----- Pre-treatment for GDEF_LOG
        call sshNLPreLogSB9(lVect   , lgpg    , vim(1, kpg),&
                            epsgPrev, epsgCurr, &
                            epslPrev, epslIncr,&
                            gn      , lamb    , logl,&
                            tPrev   , cod(kpg))
        if (cod(kpg) .ne. 0) then
            goto 999
        endif
! ----- Integrate behaviour law
        if (lMatr) then
            dtde  = 0.d0
        endif
        if (lSigm) then
            tCurr = 0.d0
        endif
        call nmcomp(BEHInteg   ,&
                    fami       , kpg        , 1        , 3       , typmod  ,&
                    imate      , compor     , carcri   , timePrev, timeCurr,&
                    6          , epslPrev   , epslIncr , 6       , tPrev   ,&
                    vim(1, kpg), option     , angl_naut,&
                    tCurr      , vip(1, kpg), 36       , dtde    ,&
                    cod(kpg))
        if (cod(kpg) .eq. 1) then
            goto 999
        endif
! ----- Post-treatment for GDEF_LOG
        call sshNLPosLogSB9(lVect , lMatr      , lgpg,&
                            tPrev , tCurr      ,&
                            gn    , lamb       , logl,&
                            dtde  , vip(1, kpg), &
                            dsidep, pk2Curr)
        dsidep(4:6,4:6) = dsidep(4:6,4:6)/2.0d0
        dsidep(4:6,1:3) = dsidep(4:6,1:3)/rac2
        dsidep(1:3,4:6) = dsidep(1:3,4:6)/rac2
        pk2Curr(4) = pk2Curr(4)/rac2
        pk2Curr(5) = pk2Curr(5)/rac2
        pk2Curr(6) = pk2Curr(6)/rac2
! ----- Compute effective shear modulus for stabilization
        call sshNLStabForcSB9(sigm, epsgPrev, dsidep, u1eff)
        Ueff = Ueff + u1eff*poids/8.d0
! ----- Geometric part of matrix
        if (lMatr) then
            if (lMatrPred) then
                sigg = sigm(1:6,kpg)
            else
                sigg = pk2Curr
            endif
            call sshRigiGeomPtSB9(nbsig , nb_node,&
                                  nb_dof,&
                                  TZETA , T      ,&
                                  zeta  , sigg   ,&
                                  kGeom)
        endif
! ----- Compute matrix at current Gauss point
        if (lMatr) then
            call sshNLMatr(nbsig    , nb_node, nb_dof,&
                           det*poids, B      , dsidep,&
                           matuu    , kGeom)
        endif
! ----- Compute internal force at current Gauss point
        if (lVect) then
            call sshNLVect(nbsig    , nb_node, nb_dof ,&
                           det*poids, B      , pk2Curr,&
                           vectu)
        endif





! ----- Compute matrix and internal force at current Gauss point
        !call sshNLVectMatr(lMatr        , lVect    , lMatrPred, lLarge,&
        !                   nbsig        , nb_node  ,&
        !                   nb_dof       , npg      ,&
        !                   zeta         , det*poids,&
        !                   B            , dsidep   ,&
        !                   T            , TZETA    ,&
        !                   sigm(1:6,kpg), pk2Curr  ,&
        !                   matuu        , vectu)
! ----- Compute stresses
        if (lSigm) then
            do i_tens = 1, 6
                sigp(i_tens, kpg) = pK2Curr(i_tens)
            end do
        endif
    enddo
!
! - Compute stabilization for matrix and internal force
!
    call sshNLStabSB9(lMatr   , lVect   , lMatrPred, lLarge,&
                      nb_node , nb_dof  ,&
                      geomInit, dispPrev, dispCurr,&
                      det     , Ueff    ,&
                      BXI     , BETA    ,&
                      BXIZETA , BETAZETA,&
                      matuu   , vectu)
!
999 continue
!
! - Return code summary
!
    call codere(cod, npg, codret)
!
end subroutine
