!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !MODULE: pops_mod.f
!
! !DESCRIPTION: This module contains variables and routines for the 
!  GEOS-Chem peristent organic pollutants (POPs) simulation. 
!\\
!\\
! !INTERFACE: 
!
      MODULE POPS_MOD
! 
! !USES:
!
      IMPLICIT NONE
! Make everything Private ...
      PRIVATE
!
! !PUBLIC TYPES:
!
      PUBLIC :: EMISSPOPS

! !PUBLIC MEMBER FUNCTIONS:
!
      PUBLIC :: CHEMPOPS
      PUBLIC :: INIT_POPS

!
! !PUBLIC DATA MEMBERS:
!

! !REVISION HISTORY:
!  20 September 2010 N.E. Selin - Initial Version
!
! !REMARKS:
! Under construction
!
!EOP

!******************************************************************************
!Comment header:
!
!  Module Variables:
!  ===========================================================================
!  (1 ) TCOSZ    (REAL*8) : Sum of COS(Solar Zenith Angle ) [unitless]
!  (2 ) TTDAY    (REAL*8) : Total daylight time at location (I,J) [minutes]
!  (3 ) ZERO_DVEL(REAL*8) : Array with zero dry deposition velocity [cm/s]
!  (4 ) COSZM    (REAL*8) : Max daily value of COS(S.Z. angle) [unitless]  
!
!  Module Routines:
!  ===========================================================================
!  (1 ) CHEMPOPS
!  (2 ) INIT_POPS
!  (3 ) CHEM_POPGP
!  (4 ) EMISSPOPS
!  (5 ) EMITPOP
!  (6 ) OHNO3TIME
!  (7 ) CLEANUP_POPS
!
!  Module Functions:
!  ===========================================================================
!
!
!  GEOS-CHEM modules referenced by pops_mod.f
!  ===========================================================================
!
!
!  Nomenclature: 
!  ============================================================================
!
!
!  POPs Tracers
!  ============================================================================
!  (1 ) POPG               : Gaseous POP - total tracer  
!  (2 ) POPPOC             : OC-sorbed POP  - total tracer
!  (3 ) POPPBC             : BC-sorbed POP  - total tracer
!
!
!  References:
!  ============================================================================
!
!
!  Notes:
!  ============================================================================
!  (1) 20 September 2010 N.E. Selin - Initial version
!  (2) 4 January 2011 C.L. Friedman - Expansion on initial version
!
!
!******************************************************************************
!
      ! References to F90 modules

      

      !=================================================================
      ! MODULE VARIABLES
      !=================================================================

      ! Parameters
      REAL*8,  PARAMETER   :: SMALLNUM = 1D-20
      ! Arrays
      REAL*8,  ALLOCATABLE :: TCOSZ(:,:)
      REAL*8,  ALLOCATABLE :: TTDAY(:,:)
      REAL*8,  ALLOCATABLE :: ZERO_DVEL(:,:)
      REAL*8,  ALLOCATABLE :: COSZM(:,:)
      REAL*8,  ALLOCATABLE :: EPOP_G(:,:,:)
      REAL*8,  ALLOCATABLE :: EPOP_OC(:,:,:)
      REAL*8,  ALLOCATABLE :: EPOP_BC(:,:,:)
      REAL*8,  ALLOCATABLE :: EPOP_P_TOT(:,:,:)
      REAL*8,  ALLOCATABLE :: POP_TOT_EM(:,:)
      REAL*8,  ALLOCATABLE :: C_OC(:,:,:),        C_BC(:,:,:)
      REAL*8,  ALLOCATABLE :: SUM_OC_EM(:,:), SUM_BC_EM(:,:)
      REAL*8,  ALLOCATABLE :: SUM_G_EM(:,:), SUM_OF_ALL(:,:)


      !=================================================================
      ! MODULE ROUTINES -- follow below the "CONTAINS" statement 
      !=================================================================
      CONTAINS

!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  CHEMPOPS
!
! !DESCRIPTION: This routine is the driver routine for POPs chemistry 
!  (eck, 9/20/10)
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE CHEMPOPS
!
! !INPUT PARAMETERS: 
!
!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
 
      ! References to F90 modules
      USE DRYDEP_MOD,    ONLY : DEPSAV
      USE ERROR_MOD,     ONLY : DEBUG_MSG
      USE GLOBAL_OH_MOD, ONLY : GET_GLOBAL_OH
      USE GLOBAL_O3_MOD, ONLY : GET_GLOBAL_O3 !clf, 6/27/2010
      USE GLOBAL_OC_MOD, ONLY : GET_GLOBAL_OC !clf, 1/20/2011
      USE GLOBAL_BC_MOD, ONLY : GET_GLOBAL_BC !clf, 1/20/2011
      USE PBL_MIX_MOD,   ONLY : GET_PBL_MAX_L
      USE LOGICAL_MOD,   ONLY : LPRT, LGTMM, LNLPBL !CDH added LNLPBL
      USE TIME_MOD,      ONLY : GET_MONTH, ITS_A_NEW_MONTH, GET_YEAR
      USE TRACER_MOD,    ONLY : N_TRACERS
      USE DRYDEP_MOD,    ONLY : DRYPOPG, DRYPOPP_OC, DRYPOPP_BC

#     include "CMN_SIZE"      ! Size parameters

!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version
!
! !REMARKS:
! (1) Based initially on CHEMMERCURY from MERCURY_MOD (eck, 9/20/10)
!
!EOP
!------------------------------------------------------------------------------
!******************************************************************************
!Comment header
!  Subroutine CHEMPOPS is the driver routine for POPs chemistry
!  in the GEOS-CHEM module. (eck, clf, 1/4/2011)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) 
!
!
!  Local variables:
!  ============================================================================
!  (1 )


!  NOTES:
!  (1 )
!******************************************************************************

!BOC

      ! Local variables
      ! LOGICAL, SAVE          :: FIRST = .TRUE.
      INTEGER                :: I, J, L, MONTH, YEAR, N, PBL_MAX

      !=================================================================
      ! CHEMPOPS begins here!
      !
      ! Read monthly mean OH fields for oxidation and monthly OC and BC
      ! fields for gas-particle partioning
      !=================================================================
      IF ( ITS_A_NEW_MONTH() ) THEN 

         ! Get the current month
         MONTH = GET_MONTH()

         ! Get the current year
         YEAR = GET_YEAR()

         ! Read monthly mean OH from disk [molecule/cm3]
         CALL GET_GLOBAL_OH( MONTH)
         IF ( LPRT ) CALL DEBUG_MSG( '### CHEMPOPS: a GET_GLOBAL_OH' )

         ! Read monthly mean O3 from disk [molecule/cm3]
         CALL GET_GLOBAL_O3( MONTH )
         IF ( LPRT ) CALL DEBUG_MSG( '### CHEMPOPS: a GET_GLOBAL_O3' )

         ! Read monthly OC from disk
         ! Do this in EMISSPOPS now
         !CALL GET_GLOBAL_OC( MONTH )
         !IF ( LPRT ) CALL DEBUG_MSG( '### CHEMPOPS: a GET_GLOBAL_OC' )

         ! Read monthly BC from disk
         ! Do this in EMISSPOPS now
         !CALL GET_GLOBAL_BC( MONTH )
         !IF ( LPRT ) CALL DEBUG_MSG( '### CHEMPOPS: a GET_GLOBAL_BC' ) 

      ENDIF
     
      ! If it's a new 6-hr mean, then get the current average 3-D temperature    

      !=================================================================
      ! Perform chemistry on POPs tracers
      !=================================================================
      
      ! Compute diurnal scaling for OH
      CALL OHNO3TIME
      IF ( LPRT ) CALL DEBUG_MSG( 'CHEMPOPS: a OHNO3TIME' )

      !-------------------------
      ! GAS AND PARTICLE PHASE chemistry
      !-------------------------
      IF ( LPRT ) CALL DEBUG_MSG( 'CHEMPOPS: b CHEM_GASPART' )
      
      ! Add option for non-local PBL (cdh, 08/27/09)
      IF ( LNLPBL ) THEN

         ! Dry deposition occurs with PBL mixing,
         ! pass zero deposition frequency
         CALL CHEM_POPGP( ZERO_DVEL, ZERO_DVEL, ZERO_DVEL)
         
      ELSE

         IF ( DRYPOPG > 0 .and. DRYPOPP_OC > 0 .and. DRYPOPP_BC > 0 )
     &      THEN
         
            ! Dry deposition active for both POP-Gas and POP-Particle; 
            ! pass drydep frequency to CHEM_POPGP (NOTE: DEPSAV has units 1/s)
            CALL CHEM_POPGP(DEPSAV(:,:,DRYPOPG), DEPSAV(:,:,DRYPOPP_OC),
     &          DEPSAV(:,:,DRYPOPP_BC) )

           ELSEIF (DRYPOPG > 0 .and. DRYPOPP_OC > 0 .and. 
     &          DRYPOPP_BC .le. 0 ) THEN

            ! Only POPG and POPP_OC dry deposition are active
            CALL CHEM_POPGP(DEPSAV(:,:,DRYPOPG), DEPSAV(:,:,DRYPOPP_OC), 
     &          ZERO_DVEL) 

           ELSEIF (DRYPOPG > 0 .and. DRYPOPP_OC .le. 0 .and. 
     &          DRYPOPP_BC > 0 ) THEN

            ! Only POPG and POPP_BC dry deposition are active
            CALL CHEM_POPGP(DEPSAV(:,:,DRYPOPG), ZERO_DVEL, 
     &          DEPSAV(:,:,DRYPOPP_BC)) 
         
           ELSEIF (DRYPOPG > 0 .and. DRYPOPP_OC .le. 0 .and. 
     &          DRYPOPP_BC .le. 0 ) THEN

            ! Only POPG dry deposition is active
            CALL CHEM_POPGP( DEPSAV(:,:,DRYPOPG), ZERO_DVEL, ZERO_DVEL) 
            
           ELSEIF (DRYPOPG <= 0 .and. DRYPOPP_OC > 0 .and. 
     &          DRYPOPP_BC > 0) THEN

            ! Only POPP dry deposition is active
            CALL CHEM_POPGP( ZERO_DVEL , DEPSAV(:,:,DRYPOPP_OC), 
     &           DEPSAV(:,:,DRYPOPP_BC))

           ELSEIF (DRYPOPG <= 0 .and. DRYPOPP_OC > 0 .and. 
     &          DRYPOPP_BC <= 0) THEN

            ! Only POPP_OC dry deposition is active
            CALL CHEM_POPGP( ZERO_DVEL , DEPSAV(:,:,DRYPOPP_OC), 
     &           ZERO_DVEL)

           ELSEIF (DRYPOPG <= 0 .and. DRYPOPP_OC <= 0 .and. 
     &          DRYPOPP_BC > 0) THEN

            ! Only POPP_OC dry deposition is active
            CALL CHEM_POPGP( ZERO_DVEL , ZERO_DVEL, 
     &           DEPSAV(:,:,DRYPOPP_BC))            
         ELSE

            ! No dry deposition, pass zero deposition frequency
            CALL CHEM_POPGP( ZERO_DVEL, ZERO_DVEL, ZERO_DVEL)

         ENDIF

      ENDIF      

      IF ( LPRT ) CALL DEBUG_MSG( 'CHEMPOPS: a CHEM_GASPART' )
   
    
      ! Return to calling program
      END SUBROUTINE CHEMPOPS

!EOC
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  CHEM_POPGP
!
! !DESCRIPTION: This routine does chemistry for POPs gas and particles
!  (eck, 9/20/10)
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE CHEM_POPGP (V_DEP_G, V_DEP_P_OC, V_DEP_P_BC)

!     References to F90 modules
      USE TRACER_MOD,   ONLY : STT,        XNUMOL
      USE TRACERID_MOD, ONLY : IDTPOPG,    IDTPOPPOC,  IDTPOPPBC
      USE DIAG53_MOD,   ONLY : AD53_PG_OC_NEG, AD53_PG_BC_NEG
      USE DIAG53_MOD,   ONLY : AD53_PG_OC_POS, AD53_PG_BC_POS
      USE DIAG53_MOD,   ONLY : ND53,       LD53,       AD53_POPG_OH
      USE DIAG53_MOD,   ONLY : AD53_POPP_OC_O3,        AD53_POPP_BC_O3
      USE TIME_MOD,     ONLY : GET_TS_CHEM
      USE DIAG_MOD,     ONLY : AD44
      USE LOGICAL_MOD,  ONLY : LNLPBL,     LGTMM
      USE PBL_MIX_MOD,  ONLY : GET_FRAC_UNDER_PBLTOP
      USE GRID_MOD,     ONLY : GET_AREA_CM2
      USE DAO_MOD,      ONLY : T,          AIRVOL
      USE ERROR_MOD,    ONLY : DEBUG_MSG

#     include "CMN_SIZE" ! Size parameters
#     include "CMN_DIAG" ! ND44

!
! !INPUT PARAMETERS: 
!
      REAL*8, INTENT(IN)    :: V_DEP_G(IIPAR,JJPAR)
      REAL*8, INTENT(IN)    :: V_DEP_P_OC(IIPAR,JJPAR)
      REAL*8, INTENT(IN)    :: V_DEP_P_BC(IIPAR,JJPAR)

!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
    
!
!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version
!
! !REMARKS:
! (1) Based initially on CHEM_HG0_HG2 from MERCURY_MOD (eck, 9/20/10)
!
!EOP
!------------------------------------------------------------------------------
!******************************************************************************
!Comment header
!  Subroutine CHEM_POPGP is the chemistry subroutine for the oxidation,
!  gas-particle partitioning, and deposition of POPs.
!  (eck, clf, 1/4/2011)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) V_DEP_G (REAL*8)    : Dry deposition frequency for gaseous POP [/s]
!  (2 ) V_DEP_P_OC (REAL*8) : Dry deposition frequency for OC-POP [/s]
!  (3 ) V_DEP_P_BC (REAL*8) : Dry deposition frequency for BC-POP [/s]
!
!  Local variables:
!  ============================================================================
!  (1 )
!
!
!     
!  NOTES:
!  (1 ) 
!  
!  REFS:
!  (1 ) For OH rate constant: Brubaker & Hites. 1998. OH reaction kinetics of
!  PAHs and PCDD/Fs. J. Phys. Chem. A. 102:915-921. 
!
!******************************************************************************
!BOC
      ! Local variables
      INTEGER               :: I, J, L
      REAL*8                :: DTCHEM,       SUM_F
      REAL*8                :: KOA_T,        KBC_T
      REAL*8                :: KOC_BC_T,     KBC_OC_T
      REAL*8                :: TK
      REAL*8                :: AREA_CM2
      REAL*8                :: F_PBL,        C_O3
      REAL*8                :: C_OH,         C_OC_CHEM,   C_BC_CHEM
      REAL*8                :: C_OC_CHEM1,   C_BC_CHEM1
      REAL*8                :: K_OH,         AIR_VOL,     K_O3
      REAL*8                :: K_OX
      REAL*8                :: E_KOX_T,       E_KOX_T_P
      REAL*8                :: K_DEPG,        K_DEPP_OC,   K_DEPP_BC
      REAL*8                :: OLD_POPG,      OLD_POPP_OC, OLD_POPP_BC
      REAL*8                :: NEW_POPG,      NEW_POPP_OC, NEW_POPP_BC
      REAL*8                :: POPG_BL,       POPP_OC_BL,  POPP_BC_BL
      REAL*8                :: POPG_FT,       POPP_OC_FT,  POPP_BC_FT
      REAL*8                :: TMP_POPG,      TMP_OX
      REAL*8                :: TMP_POPP_OC,   TMP_POPP_BC
      REAL*8                :: GROSS_OX,      GROSS_OX_OH, NET_OX
      REAL*8                :: GROSS_OX_OC,   GROSS_OX_BC
      REAL*8                :: DEP_POPG,      DEP_POPP_OC, DEP_POPP_BC
      REAL*8                :: DEP_POPG_DRY,  DEP_POPP_OC_DRY
      REAL*8                :: DEP_POPP_BC_DRY
      REAL*8                :: DEP_DRY_FLXG,  DEP_DRY_FLXP_OC
      REAL*8                :: DEP_DRY_FLXP_BC
      REAL*8                :: OLD_POP_T
      REAL*8                :: VR_OC_AIR,     VR_BC_AIR
      REAL*8                :: VR_OC_BC,      VR_BC_OC
      REAL*8                :: F_POP_OC,      F_POP_BC
      REAL*8                :: F_POP_G
      REAL*8                :: MPOP_OC,       MPOP_BC,     MPOP_G
      REAL*8                :: DIFF_G,        DIFF_OC,     DIFF_BC
      REAL*8                :: OC_AIR_RATIO,  OC_BC_RATIO, BC_AIR_RATIO
      REAL*8                :: BC_OC_RATIO,   SUM_DIFF
      REAL*8                :: TMP_OX_P_OC,   TMP_OX_P_BC
      REAL*8                :: NET_OX_OC,     NET_OX_BC

      ! Delta H for POP [kJ/mol]. Delta H is enthalpy of phase transfer
      ! from gas phase to OC. For now we use Delta H for phase transfer 
      ! from the gas phase to the pure liquid state. 
      ! For PHENANTHRENE: 
      ! this is taken as the negative of the Delta H for phase transfer
      ! from the pure liquid state to the gas phase (Schwarzenbach,
      ! Gschwend, Imboden, 2003, pg 200, Table 6.3), or -74000 [J/mol].
      ! For PYRENE:
      ! this is taken as the negative of the Delta H for phase transfer
      ! from the pure liquid state to the gas phase (Schwarzenbach,
      ! Gschwend, Imboden, 2003, pg 200, Table 6.3), or -87000 [J/mol].    
      ! For BENZO[a]PYRENE:
      ! this is also taken as the negative of the Delta H for phase transfer
      ! from the pure liquid state to the gas phase (Schwarzenbach,
      ! Gschwend, Imboden, 2003, pg 452, Prob 11.1), or -110,000 [J/mol]
      REAL*8, PARAMETER     :: DEL_H      = -87d3

      ! R = universal gas constant for adjusting KOA for temp: 8.3145 [J/mol/K]
      REAL*8, PARAMETER     :: R          = 8.31d0  

      ! KOA_298 for partitioning of gas phase POP to atmospheric OC
      ! KOA_298 = Cpop in octanol/Cpop in atmosphere at 298 K 
      ! For PHENANTHRENE:
      ! log KOA_298 = 7.64, or 4.37*10^7 [unitless]
      ! For PYRENE:
      ! log KOA_298 = 8.86, or 7.24*10^8 [unitless]
      ! For BENZO[a]PYRENE:
      ! log KOA_298 = 11.48, or 3.02*10^11 [unitless]
      ! (Ma et al., J. Chem. Eng. Data, 2010, 55:819-825).
      REAL*8, PARAMETER     :: KOA_298    = 7.24d8

      ! KBC_298 for partitioning of gas phase POP to atmospheric BC
      ! KBC_298 = Cpop in black carbon/Cpop in atmosphere at 298 K
      ! For PHENANTHRENE:
      ! log KBC_298 = 10.0, or 1.0*10^10 [unitless]
      ! For PYRENE:
      ! log KBC_298 = 11.0, or 1.0*10^11 [unitless]
      ! For BENZO[a]PYRENE:
      ! log KBC_298 = 13.9, or 7.94*10^13 [unitless]
      ! (Lohmann and Lammel, EST, 2004, 38:3793-3802)
      REAL*8, PARAMETER     :: KBC_298    = 1d11

      ! DENS_OCT = density of octanol, needed for partitioning into OC
      ! 820 [kg/m^3]
      REAL*8, PARAMETER     :: DENS_OCT   = 82d1

      ! DENS_BC = density of BC, needed for partitioning onto BC
      ! 1 [kg/L] or 1000 [kg/m^3] 
      ! From Lohmann and Lammel, Environ. Sci. Technol., 2004, 38:3793-3803.
      REAL*8, PARAMETER     :: DENS_BC    = 1d3

      ! K for reaction POPG + OH  [cm3 /molecule /s]
      ! For PHENANTHRENE: 2.70d-11
      ! (Source: Brubaker & Hites, J. Phys Chem A 1998)
      ! For PYRENE: 5.00d-11
      ! Calculated with AOPWIN
      ! For BENZO[a]PYRENE: 5.00d-11
      ! Calculated with AOPWIN 
      REAL*8, PARAMETER     :: K_POPG_OH  = 5.00d-11 !(Gas phase)

      ! k for reaction POPP + O3 [/s] depends on fitting parameters A and B. 
      ! A represents the maximum number of surface sites available to O3, and B 
      ! represents the ratio of desorption/adsorption rate coefficients for both bulk
      ! phases (Ref: Kahan et al Atm Env 2006, 40:3448)
      ! k(obs) = A x [O3(g)] / (B + [O3(g)])
      ! For PHENANTHRENE: A = 0.5 x 10^-3 s^-1, B = 2.15 x 10^15 molec/cm3
      ! For PYRENE: A = 0.7 x 10^-3 s^-1, B = 3 x 10^15 molec/cm3
      ! for BaP: A = 5.5 x 10^-3 s^-1, B = 2.8 x 10^15 molec/cm3
!      REAL*8, PARAMETER     :: AK = 7d-4 ! s^-1
!      REAL*8, PARAMETER     :: BK = 3d15 ! molec/cm3

      ! On-particle reaction scheme 3: According to Kwamena et al. (J. Phys. Chem. A 2004
      ! 108:11626), reaction will proceed with rate k = kmax(KO3)[O3]/(1+KO3[O3])
      ! For wet axelaic acid aerosols, kmax = 0.060 s^-1 and KO3 = 0.028 x 10^-13 cm3
      REAL*8, PARAMETER      :: KMAX = 0.060 ! s^-1
      REAL*8, PARAMETER      :: KO3 = 0.028d-13 ! cm^3

      ! K for reaction POPP + NO3 could be added here someday

      !=================================================================
      ! CHEM_POPGP begins here!
      !=================================================================

      ! Chemistry timestep [s]
      DTCHEM = GET_TS_CHEM() * 60d0

      DO L = 1, LLPAR
      DO J = 1, JJPAR
      DO I = 1, IIPAR

         ! Zero concentrations in loop
         MPOP_G = 0d0
         MPOP_OC = 0d0
         MPOP_BC = 0d0
         OLD_POPG = 0d0
         OLD_POPP_OC = 0d0
         OLD_POPP_BC = 0d0
         OLD_POP_T = 0d0
         NEW_POPG = 0d0
         NEW_POPP_OC = 0d0
         NEW_POPP_BC = 0d0
         POPG_BL = 0d0
         POPP_OC_BL = 0d0
         POPP_BC_BL = 0d0
         POPG_FT = 0d0
         POPP_OC_FT = 0d0
         POPP_BC_FT = 0d0
         DIFF_G = 0d0
         DIFF_OC = 0d0
         DIFF_BC = 0d0
         NET_OX = 0d0 
         TMP_POPG = 0d0
         TMP_OX = 0d0      
         GROSS_OX = 0d0
         GROSS_OX_OH = 0d0 
         DEP_POPG = 0d0
         DEP_POPP_OC = 0d0
         DEP_POPP_BC = 0d0
         DEP_POPG_DRY = 0d0
         DEP_POPP_OC_DRY = 0d0
         DEP_POPP_BC_DRY = 0d0
         DEP_DRY_FLXG = 0d0
         DEP_DRY_FLXP_OC = 0d0
         DEP_DRY_FLXP_BC = 0d0
         E_KOX_T = 0d0
         K_OX = 0d0
         K_O3 = 0d0
         GROSS_OX_OC = 0d0
         GROSS_OX_BC = 0d0

         ! Save local temperature in TK for convenience [K]
         TK = T(I,J,L)

         ! Get monthly mean OH concentrations
         C_OH        = GET_OH( I, J, L )

         ! Get monthly mean O3 concentrations
         C_O3        = GET_O3( I, J, L )

         ! Fraction of box (I,J,L) underneath the PBL top [dimensionless]
         F_PBL = GET_FRAC_UNDER_PBLTOP( I, J, L )

         ! Define K for the oxidation reaction with POPG [/s]
         K_OH        = K_POPG_OH * C_OH

         ! Define K for the oxidation reaction with POPPOC and POPPBC [/s]
         K_O3        = ( KMAX * KO3 * C_O3) / (1 + KO3 * C_O3)
         
         ! Could add K for oxidation by NO3 here one day [/s]

         ! Total K for oxidation [/s]
         K_OX        = K_OH !+ ...

         ! Define Ks for dry deposition of gas phase POP [/s]
         K_DEPG = V_DEP_G(I,J)

         ! Define Ks for dry deposition of particle phase POP [/s]
         K_DEPP_OC = V_DEP_P_OC(I,J)

         ! Define Ks for dry deposition of particle phase POP [/s]
         K_DEPP_BC = V_DEP_P_BC(I,J)

         ! Precompute exponential factors [dimensionless]
         ! For gas phase (OH):
         E_KOX_T  = EXP( -K_OX  * DTCHEM )
         ! For OC and BC phase (O3):
         E_KOX_T_P = EXP(-K_O3  * DTCHEM )

         !==============================================================
         ! GAS-PARTICLE PARTITIONING
         !==============================================================

         OLD_POPG = MAX( STT(I,J,L,IDTPOPG), SMALLNUM )  ![kg]
         OLD_POPP_OC = MAX( STT(I,J,L,IDTPOPPOC), SMALLNUM )  ![kg]
         OLD_POPP_BC = MAX( STT(I,J,L,IDTPOPPBC), SMALLNUM )  ![kg]

         ! Total POPs in box I,J,L 
         OLD_POP_T = OLD_POPG + OLD_POPP_OC + OLD_POPP_BC

         ! Define temperature-dependant partition coefficients:
         KOA_T = KOA_298 * EXP((-DEL_H/R) * ((1d0/TK) - 
     &                  (1d0/298d0))) 

         ! Define KBC_T, the BC-air partition coeff at temp T [unitless]
         ! TURN OFF TEMPERATURE DEPENDENCY FOR SENSITIVITY ANALYSIS
         KBC_T = KBC_298! * EXP((-DEL_H/R) * ((1d0/TK) - 
!     &                  (1d0/298d0)))

         ! Define KOC_BC_T, the theoretical OC-BC part coeff at temp T [unitless]
         KOC_BC_T = KOA_T / KBC_T

         ! Define KBC_OC_T, the theoretical BC_OC part coeff at temp T [unitless]
         KBC_OC_T = 1d0 / KOC_BC_T

         ! Get monthly mean OC and BC concentrations [kg/box] 
         C_OC_CHEM = GET_OC(I,J,L)
         C_BC_CHEM = GET_BC(I,J,L)

         ! Convert to units of volume per box [m^3 OC or BC/box]
         C_OC_CHEM1        = C_OC_CHEM / DENS_OCT
         C_BC_CHEM1        = C_BC_CHEM / DENS_BC

         ! Get AIRVOL
         AIR_VOL = AIRVOL(I,J,L)

         ! Define volume ratios:
         ! VR_OC_AIR = volume ratio of OC to air [unitless]     
         VR_OC_AIR   = C_OC_CHEM1 / AIR_VOL ! could be zero

         ! VR_OC_BC  = volume ratio of OC to BC [unitless]
         VR_OC_BC    = C_OC_CHEM1 / C_BC_CHEM1 ! could be zero or undefined

         ! VR_BC_AIR = volume ratio of BC to air [unitless]
         VR_BC_AIR   = VR_OC_AIR / VR_OC_BC ! could be zero or undefined

         ! VR_BC_OC  = volume ratio of BC to OC [unitless]
         VR_BC_OC    = 1d0 / VR_OC_BC ! could be zero or undefined

         ! Redefine fractions of total POPs in box (I,J,L) that are OC-phase, 
         ! BC-phase, and gas phase with new time step (should only change if 
         ! temp changes or OC/BC concentrations change) 
         OC_AIR_RATIO = 1d0 / (KOA_T * VR_OC_AIR) 
         OC_BC_RATIO = 1d0 / (KOC_BC_T * VR_OC_BC) 

         BC_AIR_RATIO = 1d0 / (KBC_T * VR_BC_AIR) 
         BC_OC_RATIO = 1d0 / (KBC_OC_T * VR_BC_OC)

         ! If there are zeros in OC or BC concentrations, make sure they
         ! don't cause problems with phase fractions
         IF ( C_OC_CHEM > SMALLNUM .and. C_BC_CHEM > SMALLNUM ) THEN
            F_POP_OC  = 1d0 / (1d0 + OC_AIR_RATIO + OC_BC_RATIO) 
            F_POP_BC  = 1d0 / (1d0 + BC_AIR_RATIO + BC_OC_RATIO)
         
           ELSE IF (C_OC_CHEM > SMALLNUM .and.
     &             C_BC_CHEM .le. SMALLNUM ) THEN
           F_POP_OC  = 1d0 / (1d0 + OC_AIR_RATIO)
           F_POP_BC  = SMALLNUM           

           ELSE IF ( C_OC_CHEM .le. SMALLNUM .and.
     &              C_BC_CHEM > SMALLNUM ) THEN
           F_POP_OC  = SMALLNUM
           F_POP_BC  = 1d0 / (1d0 + BC_AIR_RATIO)

           ELSE IF ( C_OC_CHEM .le. SMALLNUM .and. 
     &              C_BC_CHEM .le. SMALLNUM) THEN
           F_POP_OC = SMALLNUM
           F_POP_BC = SMALLNUM
        ENDIF

         ! Gas-phase:
         F_POP_G   = 1d0 - F_POP_OC - F_POP_BC

         ! Check that sum equals 1
         SUM_F = F_POP_OC + F_POP_BC + F_POP_G
         
         ! Calculate new masses of POP in each phase [kg]
         ! OC-phase:
         MPOP_OC    = F_POP_OC * OLD_POP_T

         ! BC-phase
         MPOP_BC     = F_POP_BC * OLD_POP_T

         ! Gas-phase
         MPOP_G     = F_POP_G  * OLD_POP_T

         ! Ensure new masses of POP in each phase are positive
         MPOP_OC = MAX(MPOP_OC, SMALLNUM)
         MPOP_BC = MAX(MPOP_BC, SMALLNUM)
         MPOP_G  = MAX(MPOP_G,  SMALLNUM)     

         ! Calculate differences in masses in each phase from previous time
         ! step for storage in ND53 diagnostic

            DIFF_G = MPOP_G - OLD_POPG
            DIFF_OC = MPOP_OC - OLD_POPP_OC
            DIFF_BC = MPOP_BC - OLD_POPP_BC

          ! Sum of differences should equal zero
            SUM_DIFF = DIFF_G + DIFF_OC + DIFF_BC

            !==============================================================
            ! ND53 diagnostic: Differences in distribution of gas and
            ! particle phases between time steps [kg]
            !==============================================================

            IF ( ND53 > 0 .AND. L <= LD53 ) THEN ! LD53 is max level

               IF (DIFF_OC .lt. 0) THEN
 
               AD53_PG_OC_NEG(I,J,L) = AD53_PG_OC_NEG(I,J,L)  + 
     &              DIFF_OC

               ELSE IF (DIFF_OC .eq. 0 .or. DIFF_OC .gt. 0) THEN

               AD53_PG_OC_POS(I,J,L) = AD53_PG_OC_POS(I,J,L)  + 
     &              DIFF_OC

               ENDIF

               IF (DIFF_BC .lt. 0) THEN

               AD53_PG_BC_NEG(I,J,L) = AD53_PG_BC_NEG(I,J,L)  + 
     &              DIFF_BC
               
               ELSE IF (DIFF_BC .eq. 0 .or. DIFF_BC .gt. 0) THEN

               AD53_PG_BC_POS(I,J,L) = AD53_PG_BC_POS(I,J,L)  + 
     &              DIFF_BC

               ENDIF

            ENDIF


         !==============================================================
         ! CHEMISTRY AND DEPOSITION REACTIONS
         !==============================================================
         IF ( F_PBL < 0.05D0 .OR. 
     &           K_DEPG < SMALLNUM ) THEN

               !==============================================================
               ! Entire box is in the free troposphere
               ! or deposition is turned off, so use RXN without deposition
               ! for gas phase POPs
               ! For particle POPs, rxn without deposition
               !==============================================================

               CALL RXN_OX_NODEP( MPOP_G, K_OX,
     &              E_KOX_T, NEW_POPG, GROSS_OX )

               CALL RXN_OX_NODEP( MPOP_OC, K_O3, 
     &              E_KOX_T_P, NEW_POPP_OC, GROSS_OX_OC)

               CALL RXN_OX_NODEP( MPOP_BC, K_O3, 
     &              E_KOX_T_P, NEW_POPP_BC, GROSS_OX_BC)

!               NEW_POPP_OC = MPOP_OC
!               NEW_POPP_BC = MPOP_BC

               ! No deposition occurs [kg]
               DEP_POPG = 0D0
               DEP_POPP_OC = 0D0
               DEP_POPP_BC = 0D0
               

            ELSE IF ( F_PBL > 0.95D0 ) THEN 

               !==============================================================
               ! Entire box is in the boundary layer
               ! so use RXN with deposition for gas and particle phase POPs
               !==============================================================

               CALL RXN_OX_WITHDEP( MPOP_G,   K_OX,
     &              K_DEPG,   DTCHEM,  E_KOX_T, NEW_POPG,
     &              GROSS_OX,  DEP_POPG )

               CALL RXN_OX_WITHDEP( MPOP_OC,   K_O3,
     &              K_DEPP_OC,   DTCHEM,  E_KOX_T_P, NEW_POPP_OC,
     &              GROSS_OX_OC,  DEP_POPP_OC )

               CALL RXN_OX_WITHDEP( MPOP_BC,   K_O3,
     &              K_DEPP_BC,   DTCHEM,  E_KOX_T_P, NEW_POPP_BC,
     &              GROSS_OX_BC,  DEP_POPP_BC )

!               CALL NO_RXN_WITHDEP( MPOP_OC, K_DEPP_OC, DTCHEM,
!     &              NEW_POPP_OC, DEP_POPP_OC )

!               CALL NO_RXN_WITHDEP( MPOP_BC, K_DEPP_BC, DTCHEM,
!     &              NEW_POPP_BC, DEP_POPP_BC )

            ELSE

               !==============================================================
               ! Box spans the top of the boundary layer
               ! Part of the mass is in the boundary layer and subject to 
               ! deposition while part is in the free troposphere and
               ! experiences no deposition.
               !
               ! We apportion the mass between the BL and FT according to the
               ! volume fraction of the box in the boundary layer.
               ! Arguably we should assume uniform mixing ratio, instead of
               ! uniform density but if the boxes are short, the air density
               ! doesn't change much.
               ! But assuming uniform mixing ratio across the inversion layer
               ! is a poor assumption anyway, so we are just using the
               ! simplest approach.
               !==============================================================

               ! Boundary layer portion of POPG [kg]
               POPG_BL = MPOP_G * F_PBL 

               ! Boundary layer portion of POPP_OC [kg]
               POPP_OC_BL = MPOP_OC * F_PBL

               ! Boundary layer portion of POPP_BC [kg]
               POPP_BC_BL = MPOP_BC * F_PBL

               ! Free troposphere portion of POPG [kg]
               POPG_FT = MPOP_G - POPG_BL

               ! Free troposphere portion of POPP_OC [kg]
               POPP_OC_FT = MPOP_OC - POPP_OC_BL

               ! Free troposphere portion of POPP_BC [kg]
               POPP_BC_FT = MPOP_BC - POPP_BC_BL
               
               ! Do chemistry with deposition on BL fraction for gas phase
               CALL RXN_OX_WITHDEP( POPG_BL,  K_OX,
     &              K_DEPG,   DTCHEM, E_KOX_T,
     &              NEW_POPG, GROSS_OX,  DEP_POPG )           

               ! Do chemistry without deposition on the FT fraction for gas phase
               CALL RXN_OX_NODEP( POPG_FT, K_OX,
     &              E_KOX_T, TMP_POPG, TMP_OX ) 

               ! Now do the same with the OC and BC phase:

               ! Do chemistry with deposition on BL fraction for OC phase
               CALL RXN_OX_WITHDEP( POPP_OC_BL,  K_O3,
     &              K_DEPP_OC,   DTCHEM, E_KOX_T_P,
     &              NEW_POPP_OC, GROSS_OX_OC,  DEP_POPP_OC )           

               ! Do chemistry without deposition on the FT fraction for OC phase
               CALL RXN_OX_NODEP( POPP_OC_FT, K_O3,
     &              E_KOX_T_P, TMP_POPP_OC, TMP_OX_P_OC )

               ! Do chemistry with deposition on BL fraction for BC phase
               CALL RXN_OX_WITHDEP( POPP_BC_BL,  K_O3,
     &              K_DEPP_BC,   DTCHEM, E_KOX_T_P,
     &              NEW_POPP_BC, GROSS_OX_BC,  DEP_POPP_BC )           

               ! Do chemistry without deposition on the FT fraction for BC phase
               CALL RXN_OX_NODEP( POPP_BC_FT, K_O3,
     &              E_KOX_T_P, TMP_POPP_BC, TMP_OX_P_BC )           

               ! Do deposition (no chemistry) on BL fraction for particulate phase
               ! No deposition (and no chem) on the FT fraction
               ! for the particulate phase
!               CALL NO_RXN_WITHDEP(POPP_OC_BL, K_DEPP_OC, DTCHEM,  
!     &              NEW_POPP_OC, DEP_POPP_OC)

!               CALL NO_RXN_WITHDEP(POPP_BC_BL, K_DEPP_BC, DTCHEM,  
!     &              NEW_POPP_BC, DEP_POPP_BC)
               
               ! Recombine the boundary layer and free troposphere parts [kg]
               NEW_POPG    = NEW_POPG + TMP_POPG
               NEW_POPP_OC = NEW_POPP_OC + TMP_POPP_OC
               NEW_POPP_BC = NEW_POPP_BC + TMP_POPP_BC
!               NEW_POPP_OC = NEW_POPP_OC + POPP_OC_FT
!               NEW_POPP_BC = NEW_POPP_BC + POPP_BC_FT          
               
               ! Total gross oxidation of gas phase in the BL and FT [kg]
               GROSS_OX = GROSS_OX + TMP_OX
               ! Total gross oxidation of particle phases in the BL and FT [kg]
               GROSS_OX_OC = GROSS_OX_OC + TMP_OX_P_OC
               GROSS_OX_BC = GROSS_OX_BC + TMP_OX_P_BC

            ENDIF

            ! Ensure positive concentration [kg]
            NEW_POPG    = MAX( NEW_POPG, SMALLNUM )
            NEW_POPP_OC = MAX( NEW_POPP_OC, SMALLNUM )
            NEW_POPP_BC = MAX( NEW_POPP_BC, SMALLNUM )

            ! Archive new POPG and POPP values [kg]
            STT(I,J,L,IDTPOPG)   = NEW_POPG
            STT(I,J,L,IDTPOPPOC) = NEW_POPP_OC
            STT(I,J,L,IDTPOPPBC) = NEW_POPP_BC

            ! Net oxidation [kg] (equal to gross ox for now)
            NET_OX = MPOP_G - NEW_POPG - DEP_POPG   
            NET_OX_OC = MPOP_OC - NEW_POPP_OC - DEP_POPP_OC
            NET_OX_BC = MPOP_BC - NEW_POPP_BC - DEP_POPP_BC                

            ! Error check on gross oxidation [kg]
            IF ( GROSS_OX < 0D0 .or. GROSS_OX_OC < 0d0 
     &           .or. GROSS_OX_BC < 0d0 ) 
     &          CALL DEBUG_MSG('CHEM_POPGP: negative gross oxidation')

            ! Apportion gross oxidation between OH and possibly
            ! NO3 someday [kg]
            IF ( (K_OX     < SMALLNUM) .OR. 
     &           (GROSS_OX < SMALLNUM) ) THEN
               GROSS_OX_OH = 0D0
!               GROSS_OX_NO3 = 0D0

            ELSE
               GROSS_OX_OH = GROSS_OX * K_OH / K_OX
!               GROSS_OX_NO3 = GROSS_OX * K_NO3 / K_OX
            ENDIF

            ! Apportion deposition [kg]
            ! Right now only using dry deposition (no sea salt) (clf, 1/27/11)
            ! If ever use dep with sea salt aerosols,
            ! will need to multiply DEP_POPG by the ratio 
            ! of K_DRYG (rate of dry dep) to K_DEPG (total dep rate).
            IF ( (K_DEPG  < SMALLNUM) .OR. 
     &           (DEP_POPG < SMALLNUM) ) THEN
               DEP_POPG_DRY  = 0D0
            ELSE 
               DEP_POPG_DRY  = DEP_POPG   
            ENDIF

            IF ( (K_DEPP_OC  < SMALLNUM) .OR. 
     &           (DEP_POPP_OC < SMALLNUM) ) THEN
               DEP_POPP_OC_DRY  = 0D0
            ELSE
               DEP_POPP_OC_DRY  = DEP_POPP_OC
            ENDIF

            IF ( (K_DEPP_BC  < SMALLNUM) .OR. 
     &           (DEP_POPP_BC < SMALLNUM) ) THEN
               DEP_POPP_BC_DRY  = 0D0
            ELSE
               DEP_POPP_BC_DRY  = DEP_POPP_BC 
            ENDIF

            !=================================================================
            ! ND44 diagnostic: drydep flux of POPG and POPP [molec/cm2/s]
            !=================================================================
            IF ( ( ND44 > 0 .OR. LGTMM ) .AND. (.NOT. LNLPBL) ) THEN
            ! Not using LGTMM right now (logical switch for using GTMM soil model)
            ! Also not using non-local PBL mode yet (clf, 1/27/2011)

               ! Grid box surface area [cm2]
               AREA_CM2 = GET_AREA_CM2( J )

               ! Amt of POPG lost to drydep [molec/cm2/s]
               DEP_DRY_FLXG  = DEP_POPG_DRY * XNUMOL(IDTPOPG) / 
     &              ( AREA_CM2 * DTCHEM )

               ! Archive POPG drydep flux in AD44 array [molec/cm2/s]
               AD44(I,J,IDTPOPG,1) = AD44(I,J,IDTPOPG,1) +
     &              DEP_DRY_FLXG

               ! Amt of POPPOC lost to drydep [molec/cm2/s]
               DEP_DRY_FLXP_OC = DEP_POPP_OC_DRY * 
     &                 XNUMOL(IDTPOPPOC)/( AREA_CM2 * DTCHEM )        

               ! Archive POPPOC drydep flux in AD44 array [molec/cm2/s]
               AD44(I,J,IDTPOPPOC,1) = 
     &              AD44(I,J,IDTPOPPOC,1) + DEP_DRY_FLXP_OC

               ! Amt of POPPBC lost to drydep [molec/cm2/s] 
               DEP_DRY_FLXP_BC = DEP_POPP_BC_DRY * 
     &                 XNUMOL(IDTPOPPBC)/( AREA_CM2 * DTCHEM )        

               ! Archive POPPBC drydep flux in AD44 array [molec/cm2/s]
               AD44(I,J,IDTPOPPBC,1) = 
     &              AD44(I,J,IDTPOPPBC,1) + DEP_DRY_FLXP_BC


            ENDIF
           

            !==============================================================
            ! ND53 diagnostic: Oxidized POPG (OH-POPG) production [kg]
            !==============================================================

            IF ( ND53 > 0 .AND. L <= LD53 ) THEN ! LD53 is max level

               AD53_POPG_OH(I,J,L)= AD53_POPG_OH(I,J,L) + GROSS_OX
               AD53_POPP_OC_O3(I,J,L)=AD53_POPP_OC_O3(I,J,L) + 
     &                                GROSS_OX_OC
               AD53_POPP_BC_O3(I,J,L)=AD53_POPP_BC_O3(I,J,L) + 
     &                                GROSS_OX_BC

            ENDIF

      ENDDO
      ENDDO
      ENDDO



! END OMP stuff here if added

      END SUBROUTINE CHEM_POPGP 

!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  RXN_OX_NODEP
!
! !DESCRIPTION: Subroutine RXN_OX_NODEP calculates new mass of POPG for given
! oxidation rates, without any deposition. This is for the free troposphere, or
! simulations with deposition turned off. (clf, 1/27/11, based on RXN_REDOX_NODEP
! in mercury_mod.f).
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE RXN_OX_NODEP( OLD_POPG, K_OX, E_KOX_T,
     &     NEW_POPG, GROSS_OX )
!

! !INPUT PARAMETERS: 
      REAL*8,  INTENT(IN)  :: OLD_POPG
      REAL*8,  INTENT(IN)  :: K_OX
      REAL*8,  INTENT(IN)  :: E_KOX_T
      
!
! !INPUT/OUTPUT PARAMETERS:   
!
!
! !OUTPUT PARAMETERS:
      REAL*8,  INTENT(OUT) :: NEW_POPG,  GROSS_OX
!
! !REVISION HISTORY: 
!  27 January 2011 - CL Friedman - Initial Version
!
! !REMARKS:
! (1) Based on RXN_REDOX_NODEP in mercury_mod.f
!
!EOP
!------------------------------------------------------------------------------
!******************************************************************************
!Comment header
!  Subroutine RXN_OX_NODEP calculates new mass of POPG for given
! oxidation rates, without any deposition. This is for the free troposphere, or
! simulations with deposition turned off. (clf, 1/27/11, based on RXN_REDOX_NODEP
! in mercury_mod.f).
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) OLD_POPG (REAL*8) : 
!  (2 ) DT       (REAL*8) : 
!  (3 ) K_OX     (REAL*8) :
!  (4 ) E_KOX_T  (REAL*8) :
!
!  Arguments as Output:
!  ============================================================================
!  (1 ) NEW_POPG (REAL*8) :
!  (2 ) GROSS_OX (REAL*8) :
!
!  Local variables:
!  ============================================================================
!  (1 )
!
!  NOTES:
!  (1 ) 
!  
!  REFS:
!  (1 )  
!
!******************************************************************************
!BOC
      
      ! Local variables
      ! None

      !=================================================================
      ! RXN_OX_NODEP begins here!
      !=================================================================

         !=================================================================
         ! Oxidation
         !=================================================================

         IF (K_OX < SMALLNUM ) THEN

            GROSS_OX = 0d0
            NEW_POPG = OLD_POPG

         ELSE 

         ! New concentration of POPG
         NEW_POPG = OLD_POPG * E_KOX_T

         ! Gross oxidation 
         GROSS_OX = OLD_POPG - NEW_POPG
         GROSS_OX = MAX( GROSS_OX, 0D0 )

         ENDIF

      END SUBROUTINE RXN_OX_NODEP
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  RXN_OX_WITHDEP
!
! !DESCRIPTION: Subroutine RXN_OX_WITHDEP calculates new mass of POPG for given
! rates of oxidation and deposition. This is for the boundary layer.
! (clf, 1/27/11, based on RXN_REDOX_NODEP in mercury_mod.f).
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE RXN_OX_WITHDEP( OLD_POPG, K_OX, K_DEPG, DT, E_KOX_T,
     &     NEW_POPG, GROSS_OX, DEP_POPG )
!
      ! References to F90 modules
      USE ERROR_MOD,    ONLY : ERROR_STOP


! !INPUT PARAMETERS: 
      REAL*8,  INTENT(IN)  :: OLD_POPG,  DT
      REAL*8,  INTENT(IN)  :: K_OX, K_DEPG
      REAL*8,  INTENT(IN)  :: E_KOX_T
      
!
! !INPUT/OUTPUT PARAMETERS:   
!
!
! !OUTPUT PARAMETERS:
      REAL*8,  INTENT(OUT) :: NEW_POPG,  GROSS_OX
      REAL*8,  INTENT(OUT) :: DEP_POPG
!
! !REVISION HISTORY: 
!  27 January 2011 - CL Friedman - Initial Version
!
! !REMARKS:
! (1) Based on RXN_REDOX_WITHDEP in mercury_mod.f
!
!EOP
!------------------------------------------------------------------------------
!******************************************************************************
!Comment header
!  Subroutine RXN_OX_WITHDEP calculates new mass of POPG for given
! rates of oxidation and deposition. This is for the boundary layer.
! (clf, 1/27/11, based on RXN_REDOX_WITHDEP in mercury_mod.f).
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) OLD_POPG (REAL*8) : 
!  (2 ) DT       (REAL*8) : 
!  (3 ) K_OX     (REAL*8) :
!  (4 ) K_DEPG   (REAL*8) :
!  (5 ) E_KOX_T  (REAL*8) :
!
!  Arguments as Output:
!  ============================================================================
!  (1 ) NEW_POPG (REAL*8) :
!  (2 ) GROSS_OX (REAL*8) :
!  (3 ) DEP_POPG (REAL*8) :
!
!  Local variables:
!  ============================================================================
!  (1 )
!
!  NOTES:
!  (1 ) 
!  
!  REFS:
!  (1 )  
!
!******************************************************************************
!BOC
      
      ! Local variables
      REAL*8               :: E_KDEPG_T
      REAL*8               :: NEWPOPG_OX
      REAL*8               :: NEWPOPG_DEP

      !=================================================================
      ! RXN_OX_WITHDEP begins here!
      !=================================================================

      ! Precompute exponential factor for deposition [dimensionless]
      E_KDEPG_T = EXP( -K_DEPG * DT )

      IF (K_OX < SMALLNUM) THEN     
         
         !=================================================================
         ! No Chemistry, Deposition only
         !=================================================================

         ! New mass of POPG [kg]
         NEW_POPG = OLD_POPG * E_KDEPG_T
         
         ! Oxidation of POPG [kg]
         GROSS_OX = 0D0

         ! Deposited POPG [kg]
         DEP_POPG = OLD_POPG - NEW_POPG

      ELSE

         !=================================================================
         ! Oxidation and Deposition 
         !=================================================================

         ![POPG](t) = [POPG](0) exp( -(kOx + kDPOPG) t)
         !Ox(t)     = ( [POPG](0) - [POPG](t) ) * kOx / ( kOx + kDPOPG )
         !Dep_POPG(t)   = ( [POPG](0) - [POPG](t) - Ox(t) ) 

         ! New concentration of POPG [kg]
         NEW_POPG = OLD_POPG * E_KOX_T * E_KDEPG_T

         ! Gross oxidized gas phase mass [kg]
         GROSS_OX = ( OLD_POPG - NEW_POPG ) * K_OX / ( K_OX + K_DEPG )
         GROSS_OX = MAX( GROSS_OX, 0D0 )

         ! POPG deposition [kg]
         DEP_POPG = ( OLD_POPG - NEW_POPG - GROSS_OX )       
         DEP_POPG = MAX( DEP_POPG, 0D0 )

      ENDIF

      END SUBROUTINE RXN_OX_WITHDEP
!EOC
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  NO_RXN_WITHDEP
!
! !DESCRIPTION: Subroutine NO_RXN_WITHDEP calculates new mass of POPP for given
! rate of deposition. No oxidation of POPP. This is for the boundary layer.
! (clf, 2/9/11)
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE NO_RXN_WITHDEP( OLD_POPP, K_DEPP, DT,
     &     NEW_POPP, DEP_POPP )
!
      ! References to F90 modules
      USE ERROR_MOD,    ONLY : ERROR_STOP


! !INPUT PARAMETERS: 
      REAL*8,  INTENT(IN)  :: OLD_POPP
      REAL*8,  INTENT(IN)  :: K_DEPP
      REAL*8,  INTENT(IN)  :: DT
      
!
! !INPUT/OUTPUT PARAMETERS:   
!
!
! !OUTPUT PARAMETERS:
      REAL*8,  INTENT(OUT) :: NEW_POPP
      REAL*8,  INTENT(OUT) :: DEP_POPP
!
! !REVISION HISTORY: 
!  9 February 2011 - CL Friedman - Initial Version
!
! !REMARKS:
!
!EOP
!------------------------------------------------------------------------------
!******************************************************************************
!Comment header
!  Subroutine NO_RXN_WITHDEP calculates new mass of POPP for given
! rate of deposition. This is for the boundary layer.
! (clf, 1/27/11, based on RXN_REDOX_NODEP in mercury_mod.f).
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) OLD_POPP (REAL*8) : 
!  (2 ) K_DEPP   (REAL*8) :
!  (3 ) DT       (REAL*8) :
!
!  Arguments as Output:
!  ============================================================================
!  (1 ) NEW_POPP (REAL*8) :
!  (2 ) DEP_POPP (REAL*8) :
!
!  Local variables:
!  ============================================================================
!  (1 )
!
!  NOTES:
!  (1 ) 
!  
!  REFS:
!  (1 )  
!
!******************************************************************************
!BOC
      
      ! Local variables
      REAL*8               :: E_KDEPP_T

      !=================================================================
      ! NO_RXN_WITHDEP begins here!
      !=================================================================

      ! Precompute exponential factors [dimensionless]
      E_KDEPP_T = EXP( -K_DEPP * DT )     

      !=================================================================
      ! No Chemistry, Deposition only
      !=================================================================

      ! New mass of POPP [kg]
      NEW_POPP = OLD_POPP * E_KDEPP_T

      ! POPP deposition [kg]
      DEP_POPP = OLD_POPP - NEW_POPP
      DEP_POPP = MAX( DEP_POPP, 0D0 )


      END SUBROUTINE NO_RXN_WITHDEP
!EOC

!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  EMISSPOPS
!
! !DESCRIPTION: This routine is the driver routine for POPs emissions
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE EMISSPOPS
!
! !INPUT PARAMETERS: 
!

!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version
!
! !REMARKS:
! (1) Based initially on EMISSMERCURY from MERCURY_MOD (eck, 9/20/10)
!
!EOP
!------------------------------------------------------------------------------
!******************************************************************************
!Comment header
!  Subroutine EMISSPOPS is the driver subroutine for POPs emissions.
!  !
!  Arguments as Input:
!  ============================================================================
!  (1 )
!
!  Local variables:
!  ============================================================================
!  (1 ) I, J, L   (INTEGER) : Long, lat, level
!  (2 ) N         (INTEGER) : Tracer ID
!  (3 ) PBL_MAX   (INTEGER) : Maximum extent of boundary layer [level]
!  (4 ) DTSRCE    (REAL*8)  : Emissions time step  [s]
!  (5 ) T_POP     (REAL*8)  : POP emission rate [kg/s]
!  (6 ) E_POP     (REAL*8)  : POPs emitted into box [kg]
!  (7 ) F_OF_PBL  (REAL*8)  : Fraction of box within boundary layer [unitless]
!     
!  NOTES:
!  (1 ) 
!  
!  REFS:
!  (1 )
!******************************************************************************
!BOC
      ! References to F90 modules
      USE ERROR_MOD,         ONLY : DEBUG_MSG, ERROR_STOP
      USE LOGICAL_MOD,       ONLY : LPRT, LNLPBL !CDH added LNLPBL
      USE TIME_MOD,          ONLY : GET_MONTH, ITS_A_NEW_MONTH, GET_YEAR
      USE TRACER_MOD,        ONLY : STT
      USE VDIFF_PRE_MOD,     ONLY : EMIS_SAVE !cdh for LNLPBL
      USE GRID_MOD,          ONLY : GET_XMID, GET_YMID
      USE DAO_MOD,           ONLY : T, AIRVOL
      USE GLOBAL_OC_MOD,     ONLY : GET_GLOBAL_OC
      USE GLOBAL_BC_MOD,     ONLY : GET_GLOBAL_BC
      ! Reference to diagnostic arrays
      USE DIAG53_MOD,   ONLY : AD53, ND53
      USE PBL_MIX_MOD,  ONLY : GET_FRAC_OF_PBL, GET_PBL_MAX_L
      USE TIME_MOD,     ONLY : GET_TS_EMIS
      USE TRACERID_MOD, ONLY : IDTPOPG, IDTPOPPOC,  IDTPOPPBC
      
#     include "CMN_SIZE"     ! Size parameters
#     include "CMN_DEP"      ! FRCLND

      ! Local variables
      INTEGER               :: I,   J,    L,    N,    PBL_MAX
      INTEGER               :: MONTH, YEAR
      REAL*8                :: DTSRCE, F_OF_PBL, TK
      REAL*8                :: E_POP, T_POP
      REAL*8                :: C_OC1,   C_BC1,  AIR_VOL
      REAL*8                :: C_OC2,   C_BC2
      REAL*8                :: F_POP_OC, F_POP_BC 
      REAL*8                :: F_POP_G
      REAL*8                :: KOA_T, KBC_T, KOC_BC_T, KBC_OC_T
      REAL*8                :: VR_OC_AIR, VR_OC_BC
      REAL*8                :: VR_BC_AIR, VR_BC_OC, SUM_F
      REAL*8                :: OC_AIR_RATIO, OC_BC_RATIO
      REAL*8                :: BC_AIR_RATIO, BC_OC_RATIO
      REAL*8                :: MAXVAL_EMISSPOPS
      REAL*8                :: MINVAL_EMISSPOPS
      LOGICAL, SAVE         :: FIRST = .TRUE.

      ! Delta H for POP [kJ/mol]. Delta H is enthalpy of phase transfer
      ! from gas phase to OC. For now we use Delta H for phase transfer 
      ! from the gas phase to the pure liquid state. 
      ! For PHENANTHRENE: 
      ! this is taken as the negative of the Delta H for phase transfer
      ! from the pure liquid state to the gas phase (Schwarzenbach,
      ! Gschwend, Imboden, 2003, pg 200, Table 6.3), or -74000 [J/mol].
      ! For PYRENE:
      ! this is taken as the negative of the Delta H for phase transfer
      ! from the pure liquid state to the gas phase (Schwarzenbach,
      ! Gschwend, Imboden, 2003, pg 200, Table 6.3), or -87000 [J/mol].    
      ! For BENZO[a]PYRENE:
      ! this is also taken as the negative of the Delta H for phase transfer
      ! from the pure liquid state to the gas phase (Schwarzenbach,
      ! Gschwend, Imboden, 2003, pg 452, Prob 11.1), or -110,000 [J/mol]
      REAL*8, PARAMETER     :: DEL_H      = -87d3

      ! R = universal gas constant for adjusting KOA for temp: 8.3145 [J/mol/K]
      REAL*8, PARAMETER     :: R          = 8.31d0  

      ! KOA_298 for partitioning of gas phase POP to atmospheric OC
      ! KOA_298 = Cpop in octanol/Cpop in atmosphere at 298 K 
      ! For PHENANTHRENE:
      ! log KOA_298 = 7.64, or 4.37*10^7 [unitless]
      ! For PYRENE:
      ! log KOA_298 = 8.86, or 7.24*10^8 [unitless]
      ! For BENZO[a]PYRENE:
      ! log KOA_298 = 11.48, or 3.02*10^11 [unitless]
      ! (Ma et al., J. Chem. Eng. Data, 2010, 55:819-825).
      REAL*8, PARAMETER     :: KOA_298    = 7.24d8

      ! KBC_298 for partitioning of gas phase POP to atmospheric BC
      ! KBC_298 = Cpop in black carbon/Cpop in atmosphere at 298 K
      ! For PHENANTHRENE:
      ! log KBC_298 = 10.0, or 1.0*10^10 [unitless]
      ! For PYRENE:
      ! log KBC_298 = 11.0, or 1.0*10^11 [unitless]
      ! For BENZO[a]PYRENE:
      ! log KBC_298 = 13.9, or 7.94*10^13 [unitless]
      ! (Lohmann and Lammel, EST, 2004, 38:3793-3802)
      REAL*8, PARAMETER     :: KBC_298    = 1d11

      ! DENS_OCT = density of octanol, needed for partitioning into OC
      ! 820 [kg/m^3]
      REAL*8, PARAMETER     :: DENS_OCT   = 82d1

      ! DENS_BC = density of BC, needed for partitioning onto BC
      ! 1 [kg/L] or 1000 [kg/m^3]
      ! From Lohmann and Lammel, Environ. Sci. Technol., 2004, 38:3793-3803.
      REAL*8, PARAMETER     :: DENS_BC    = 1d3


      !=================================================================
      ! EMISSPOPS begins here!
      !=================================================================

      CALL INIT_POPS 

      ! First-time initialization
      IF ( FIRST ) THEN

         ! Read anthro emissions from disk
         !CALL INIT_POPS 
         CALL POPS_READYR

         ! Reset first-time flag
         FIRST = .FALSE.
      ENDIF

      !=================================================================
      ! Read monthly OC and BC fields for gas-particle partioning
      !=================================================================
      IF ( ITS_A_NEW_MONTH() ) THEN 

         ! Get the current month
         MONTH = GET_MONTH()

         ! Get the current month
         YEAR = GET_YEAR()

         ! Read monthly OC and BC from disk
         CALL GET_GLOBAL_OC( MONTH, YEAR )
         IF ( LPRT ) CALL DEBUG_MSG( '### CHEMPOPS: a GET_GLOBAL_OC' )

         CALL GET_GLOBAL_BC( MONTH, YEAR )
         IF ( LPRT ) CALL DEBUG_MSG( '### CHEMPOPS: b GET_GLOBAL_BC' )

      ENDIF

      ! If we are using the non-local PBL mixing,
      ! we need to initialize the EMIS_SAVE array (cdh, 08/27/09)
      IF (LNLPBL) EMIS_SAVE = 0d0

      ! Emission timestep [s]
      DTSRCE  = GET_TS_EMIS() * 60d0

      ! Maximum extent of the PBL [model level]
      PBL_MAX = GET_PBL_MAX_L() 

      ! Loop over grid boxes
      DO J = 1, JJPAR
      DO I = 1, IIPAR          

!            CALL FLUSH (6)  

         F_OF_PBL = 0d0 
         T_POP = 0d0       

         !Here, save the total from the emissions array
         !into the T_POP variable [kg/s]
         T_POP = POP_TOT_EM(I,J)


         !==============================================================
         ! Apportion total POPs emitted to gas phase, OC-bound, and BC-bound
         ! emissions (clf, 2/1/2011)         
         ! Then partition POP throughout PBL; store into STT [kg]
         ! Now make sure STT does not underflow (cdh, bmy, 4/6/06; eck 9/20/10)
         !==============================================================

         ! Loop up to max PBL level
         DO L = 1, PBL_MAX

            !Get temp [K]
            TK = T(I,J,L)

            ! Define temperature-dependent partition coefficients:
            ! KOA_T, the octanol-air partition coeff at temp T [unitless]
            KOA_T = KOA_298 * EXP((-DEL_H/R) * ((1d0/TK) - 
     &              (1d0/298d0)))

            ! Define KBC_T, the BC-air partition coeff at temp T [unitless]
            ! TURN OFF TEMPERATURE DEPENDENCY FOR SENSITIVITY ANALYSIS
            KBC_T = KBC_298 * EXP((-DEL_H/R) * ((1d0/TK) - 
     &              (1d0/298d0)))

            ! Define KOC_BC_T, the theoretical OC-BC part coeff at temp T [unitless]
            KOC_BC_T = KOA_T / KBC_T

            ! Define KBC_OC_T, the theoretical BC_OC part coeff at temp T [unitless]
            KBC_OC_T = 1d0 / KOC_BC_T

           ! Get monthly mean OC and BC concentrations [kg/box]
            C_OC1        = GET_OC( I, J, L )
            C_BC1        = GET_BC( I, J, L )
           
            ! Convert C_OC and C_BC units to volume per box 
            ! [m^3 OC or BC/box]
            !C_OC(I,J,L)        = GET_OC(I,J,L) / DENS_OCT
            !C_BC(I,J,L)        = GET_BC(I,J,L) / DENS_BC
            C_OC2        = C_OC1 / DENS_OCT
            C_BC2        = C_BC1 / DENS_BC

            ! Get air volume (m^3)
            AIR_VOL     = AIRVOL(I,J,L) 

            ! Define volume ratios:
            ! VR_OC_AIR = volume ratio of OC to air [unitless]    
            VR_OC_AIR = C_OC2 / AIR_VOL

            ! VR_OC_BC  = volume ratio of OC to BC [unitless]
            VR_OC_BC    = C_OC2 / C_BC2

            ! VR_BC_AIR = volume ratio of BC to air [unitless]
            VR_BC_AIR   = VR_OC_AIR / VR_OC_BC

            ! VR_BC_OC  = volume ratio of BC to OC [unitless]
            !VR_BC_OC(I,J,L)    = 1d0 / VR_OC_BC(I,J,L)
            VR_BC_OC    = 1d0 / VR_OC_BC 

            ! Redefine fractions of total POPs in box (I,J,L) that are OC-phase, 
            ! BC-phase, and gas phase with new time step (should only change if 
            ! temp changes or OC/BC concentrations change) 
            OC_AIR_RATIO = 1d0 / (KOA_T * VR_OC_AIR) 
            OC_BC_RATIO = 1d0 / (KOC_BC_T * VR_OC_BC) 
  
            BC_AIR_RATIO = 1d0 / (KBC_T * VR_BC_AIR) 
            BC_OC_RATIO = 1d0 / (KBC_OC_T * VR_BC_OC)

            ! If there are zeros in OC or BC concentrations, make sure they
            ! don't cause problems with phase fractions
            IF ( C_OC1 > SMALLNUM .and. C_BC1 > SMALLNUM ) THEN
               F_POP_OC  = 1d0 / (1d0 + OC_AIR_RATIO + OC_BC_RATIO) 
               F_POP_BC  = 1d0 / (1d0 + BC_AIR_RATIO + BC_OC_RATIO)
         
             ELSE IF (C_OC1 > SMALLNUM .and.
     &             C_BC1 .le. SMALLNUM ) THEN
             F_POP_OC  = 1d0 / (1d0 + OC_AIR_RATIO)
             F_POP_BC  = SMALLNUM           

             ELSE IF ( C_OC1 .le. SMALLNUM .and.
     &             C_BC1 > SMALLNUM ) THEN
             F_POP_OC  = SMALLNUM
             F_POP_BC  = 1d0 / (1d0 + BC_AIR_RATIO)

             ELSE IF ( C_OC1 .le. SMALLNUM .and. 
     &             C_BC1 .le. SMALLNUM) THEN
             F_POP_OC = SMALLNUM
             F_POP_BC = SMALLNUM
            ENDIF

            ! Gas-phase:
            F_POP_G   = 1d0 - F_POP_OC - F_POP_BC

            ! Check that sum of fractions equals 1
            SUM_F = F_POP_OC + F_POP_BC + F_POP_G                
            
            ! Fraction of PBL that box (I,J,L) makes up [unitless]
            F_OF_PBL    = GET_FRAC_OF_PBL(I,J,L)

            ! Calculate rates of POP emissions in each phase [kg/s]
            ! OC-phase:
            EPOP_OC(I,J,L) = F_POP_OC * F_OF_PBL * T_POP                        

            ! BC-phase
            EPOP_BC(I,J,L) = F_POP_BC * F_OF_PBL * T_POP                         

            ! Gas-phase
            EPOP_G(I,J,L)  = F_POP_G * F_OF_PBL * T_POP
        

            !-----------------
            ! OC-PHASE EMISSIONS
            !-----------------
            N           = IDTPOPPOC
            E_POP       = EPOP_OC(I,J,L) * DTSRCE
            CALL EMITPOP( I, J, L, N, E_POP )

            !-----------------
            ! BC-PHASE EMISSIONS
            !-----------------
            N           = IDTPOPPBC
            E_POP       = EPOP_BC(I,J,L) * DTSRCE
            CALL EMITPOP( I, J, L, N, E_POP )

            !-----------------
            ! GASEOUS EMISSIONS
            !-----------------
            N           = IDTPOPG
            E_POP       = EPOP_G(I,J,L) * DTSRCE
            CALL EMITPOP( I, J, L, N, E_POP )
             
            ENDDO


         !==============================================================
         ! Sum different POPs emissions phases (OC, BC, and gas phase)
         ! through bottom layer to top of PBL for storage in ND53 diagnostic
         !==============================================================

           SUM_OC_EM(I,J) =  SUM(EPOP_OC(I,J,1:PBL_MAX))  
           SUM_BC_EM(I,J) =  SUM(EPOP_BC(I,J,1:PBL_MAX))
           SUM_G_EM(I,J)  =  SUM(EPOP_G(I,J,1:PBL_MAX))           
       
         SUM_OF_ALL(I,J) = SUM_OC_EM(I,J) + SUM_BC_EM(I,J) + 
     &                      SUM_G_EM(I,J)

         ! Check that sum thru PBL is equal to original emissions array
         SUM_OF_ALL(I,J) = POP_TOT_EM(I,J) / SUM_OF_ALL(I,J)
        

         !==============================================================
         ! ND53 diagnostic: POP emissions [kg]
         ! 1 = total;  2 = OC;  3 = BC;  4 = gas phase
         !==============================================================
         IF ( ND53 > 0 ) THEN
            AD53(I,J,1) = AD53(I,J,1) + (T_POP * DTSRCE)
            AD53(I,J,2) = AD53(I,J,2) + (SUM_OC_EM(I,J) * DTSRCE)
            AD53(I,J,3) = AD53(I,J,3) + (SUM_BC_EM(I,J) * DTSRCE)
            AD53(I,J,4) = AD53(I,J,4) + (SUM_G_EM(I,J) * DTSRCE)
         ENDIF
         
      ENDDO
      ENDDO


      ! Return to calling program
      END SUBROUTINE EMISSPOPS

!EOC
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  EMITPOP
!
! !DESCRIPTION: This routine directs emission either to STT directly or to EMIS_SAVE
!  for use by the non-local PBL mixing. This is a programming convenience.
!  (cdh, 08/27/09, modified for pops by eck, 9/20/10)
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE EMITPOP( I, J, L, ID, E_POP )
!! 
! !USES:
      ! Reference to diagnostic arrays
      USE TRACER_MOD,   ONLY : STT
      USE LOGICAL_MOD,  ONLY : LNLPBL
      USE VDIFF_PRE_MOD,ONLY : EMIS_SAVE
! !INPUT PARAMETERS: 
      INTEGER, INTENT(IN)   :: I, J, L, ID
      REAL*8,  INTENT(IN)   :: E_POP
!
!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version
!
! !REMARKS:
! (1) Based initially on EMITHG from MERCURY_MOD (eck, 9/20/10)
!
!EOP
!******************************************************************************
!Comment header
!  Subroutine EMITPOP directs emission either to STT directly or to EMIS_SAVE
!  for use by the non-local PBL mixing. This is a programming convenience.
!  (cdh, 08/27/09, modified for pops by eck, 9/20/10)
!  
!  Arguments as Input:
!  ============================================================================
!  (1 ) I, J, L            INTEGERS  Grid box dimensions
!  (2 ) ID                 INTEGER   Tracer ID
!  (3 ) E_POP              REAL*8    POP emissions [kg/s]
!
!  Local variables:
!  ============================================================================
!  (1 ) 
!     
!  NOTES:
!  (1 ) Based on EMITHG in mercury_mod.f
!  
!  REFS:
!  (1 )

!------------------------------------------------------------------------------
!BOC
      !=================================================================
      ! EMITPOP begins here!
      !=================================================================

      ! Save emissions [kg/s] for non-local PBL mixing or emit directly.
      ! Make sure that emitted mass is non-negative
      ! This is here only for consistency with old code which warned of
      ! underflow error (cdh, 08/27/09, modified for POPs 9/20/10)
      IF (LNLPBL) THEN
         EMIS_SAVE(I,J,ID) = EMIS_SAVE(I,J,ID) + MAX( E_POP, 0D0 )
      ELSE
          STT(I,J,L,ID) = STT(I,J,L,ID) + E_POP
      ENDIF

      END SUBROUTINE EMITPOP
!EOC
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  POPS_READYR
!
! !DESCRIPTION: 
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE POPS_READYR
!! 
! !USES:
      ! References to F90 modules
      USE BPCH2_MOD,         ONLY : READ_BPCH2, GET_TAU0
      USE DIRECTORY_MOD,     ONLY : DATA_DIR_1x1
      USE REGRID_1x1_MOD,    ONLY : DO_REGRID_1x1
      USE TIME_MOD,          ONLY : EXPAND_DATE
    
! !INPUT PARAMETERS: 
!
!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  3 February 2011 - CL Friedman - Initial Version
!
! !REMARKS:
! (1) Based initially on MERCURY_READYR from MERCURY_MOD (clf, 2/3/2011)
!
!EOP
!******************************************************************************
!Comment header
!  Subroutine POP_READYR read the year-invariant emissions for POPs (PAHs) from 
!  all sources combined
!  
!  Arguments as Input:
!  ============================================================================
!  (1 ) 
!
!  Local variables:
!  ============================================================================
!  (1 ) 
!     
!  NOTES:
!  (1 ) Based on MERCURY_READYR in mercury_mod.f
!  
!  REFS:
!  (1 ) Zhang, Y. and Tao, S. 2009. Global atmospheric emission inventory
!  of polycyclic aromatic hydrocarbons (PAHs) for 2004. Atm Env. 43:812-819.

!------------------------------------------------------------------------------
!BOC
#     include "CMN_SIZE"       ! Size parameters

      ! Local variables
      REAL*4               :: ARRAY(I1x1,J1x1,1) 
      REAL*8               :: XTAU, MAX_A, MIN_A
      REAL*8               :: MAX_B, MIN_B
      REAL*8, PARAMETER    :: SEC_PER_YR = 365.35d0 * 86400d0  
      CHARACTER(LEN=225)   :: FILENAME 
      INTEGER              :: NYMD

      !=================================================================
      ! POP_READYR begins here!
      !=================================================================

      
      ! POLYCYCLIC AROMATIC HYDROCARBONS (PAHS):
      ! PAH emissions are for the year 2004
      ! Each PAH congener is emitted individually and contained in separate
      ! files
 
      ! Filename for congener you wish to model:
      !FILENAME = TRIM( DATA_DIR_1x1 )       // 
!     &           'PAHs_2004/PHE_EM_4x5.bpch' 
      FILENAME = '/net/fs03/d0/geosdata/data/GEOS_4x5/PAHs_2004/' //
     &           '1x1/updated060911/PYR_EM_1x1.bpch'

      
      ! Timestamp for emissions
      ! All PAH emissions are for the year 2004
      XTAU = GET_TAU0( 1, 1, 2004) 

      ! Echo info
      WRITE( 6, 100 )
100        FORMAT( '     - POPS_READYR: Reading ', a )

       ! Read data in [Mg/yr]
       CALL READ_BPCH2( FILENAME, 'PG-SRCE', 1, 
     &           XTAU,      I1x1,     J1x1,    
     &           1,         ARRAY,   QUIET=.FALSE. )

       ! Cast to REAL*8 and resize       
       CALL DO_REGRID_1x1( 'kg', ARRAY, POP_TOT_EM )  

       ! Convert from [Mg/yr] to [kg/s]
       POP_TOT_EM = POP_TOT_EM * 1000d0 / SEC_PER_YR
      
      ! Return to calling program
      END SUBROUTINE POPS_READYR

!EOC
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------

      FUNCTION GET_O3( I, J, L ) RESULT( O3_MOLEC_CM3 )
!
!******************************************************************************
!  Function GET_O3 returns monthly mean O3 for offline sulfate aerosol
!  simulations. (bmy, 12/16/02)
!
!  Arguments as Input:
!  ============================================================================
!  (1-3) I, J, L   (INTEGER) : Grid box indices for lon, lat, vertical level
!
!  NOTES:
!  (1 ) We assume SETTRACE has been called to define IDO3. (bmy, 12/16/02)
!  (2 ) Now reference inquiry functions from "tracer_mod.f" (bmy, 7/20/04)
!******************************************************************************
!
      ! References to F90 modules
      USE DAO_MOD,       ONLY : AD
      USE GLOBAL_O3_MOD, ONLY : O3

#     include "CMN_SIZE"  ! Size parameters

      ! Arguments
      INTEGER, INTENT(IN) :: I, J, L

      ! Local variables
      REAL*8              :: O3_MOLEC_CM3

      ! External functions
      REAL*8, EXTERNAL    :: BOXVL
      
      !=================================================================
      ! GET_O3 begins here!
      !=================================================================

      ! Get ozone [v/v] for this gridbox & month
      ! and convert to [molec/cm3] (eck, 12/2/04)
      O3_MOLEC_CM3 = O3(I,J,L) * ( 6.022d23 / 28.97d-3 ) * 
     &               AD(I,J,L)  /  BOXVL(I,J,L)

      ! Return to calling program
      END FUNCTION GET_O3

!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  GET_OH
!
! !DESCRIPTION: Function GET_OH returns monthly mean OH and imposes a diurnal
! variation. 
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_OH( I, J, L ) RESULT( OH_MOLEC_CM3 )

      ! References to F90 modules
      USE DAO_MOD,       ONLY : SUNCOS 
      USE GLOBAL_OH_MOD, ONLY : OH
      USE TIME_MOD,      ONLY : GET_TS_CHEM

#     include "CMN_SIZE"  ! Size parameters

! !INPUT PARAMETERS: 

      INTEGER, INTENT(IN) :: I, J, L
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  03 February 2011 - CL Friedman - Initial Version
!
! !REMARKS:
! Copied GET_OH function from mercury_mod.f - CLF
!
!EOP
!------------------------------------------------------------------------------
!BOC

       ! Local variables
       INTEGER       :: JLOOP
       REAL*8        :: OH_MOLEC_CM3
    
       !=================================================================
       ! GET_OH begins here!
       !=================================================================

       ! 1-D grid box index for SUNCOS
       JLOOP = ( (J-1) * IIPAR ) + I

       ! Test for sunlight...
       IF ( SUNCOS(JLOOP) > 0d0 .and. TCOSZ(I,J) > 0d0 ) THEN

         ! Impose a diurnal variation on OH during the day
         OH_MOLEC_CM3 = OH(I,J,L)                      *           
     &                  ( SUNCOS(JLOOP) / TCOSZ(I,J) ) *
     &                  ( 1440d0        / GET_TS_CHEM() )

         ! Make sure OH is not negative
         OH_MOLEC_CM3 = MAX( OH_MOLEC_CM3, 0d0 )
               
       ELSE

         ! At night, OH goes to zero
         OH_MOLEC_CM3 = 0d0

       ENDIF

       ! Return to calling program
       END FUNCTION GET_OH
!EOC

!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  GET_OC
!
! !DESCRIPTION: Function GET_OC returns monthly mean organic carbon 
! concentrations [kg/box]
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_OC( I, J, L) RESULT( C_OC )
!
! !INPUT PARAMETERS:

!     References to F90 modules
      USE GLOBAL_OC_MOD, ONLY : OC 

      INTEGER, INTENT(IN) :: I, J, L 
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  03 February 2011 - CL Friedman - Initial Version
!
! !REMARKS:
! Test
!
!EOP
!------------------------------------------------------------------------------
!BOC
      ! Local variables
      REAL*8            :: C_OC

      !=================================================================
      ! GET_OC begins here!
      !=================================================================

      ! Get organic carbon concentration [kg/box] for this gridbox and month
      C_OC = OC(I,J,L)

      ! Make sure OC is not negative
      C_OC = MAX( C_OC, 0d0 )

      ! Return to calling program
      END FUNCTION GET_OC
!EOC

!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            !
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  GET_BC
!
! !DESCRIPTION: Function GET_BC returns monthly mean black carbon concentrations
! [kg/box]
!\\
!\\
! !INTERFACE:
!
      FUNCTION GET_BC( I, J, L) RESULT( C_BC )

!
! !INPUT PARAMETERS: 
!
      ! References to F90 modules
      USE GLOBAL_BC_MOD, ONLY : BC
   
      INTEGER, INTENT(IN) :: I, J, L   
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  03 February 2011 - CL Friedman - Initial Version
!
! !REMARKS:
! Test
!
!EOP
!------------------------------------------------------------------------------
!BOC

      ! Local variables
      REAL*8      :: C_BC    
    
      !=================================================================
      ! GET_BC begins here!
      !=================================================================

      ! Get black carbon concentration [kg/box] for this gridbox and month
      C_BC = BC(I,J,L)

      ! Return to calling program

      END FUNCTION GET_BC
!EOC

!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  OHNO3TIME
!
! !DESCRIPTION: Subroutine OHNO3TIME computes the sum of cosine of the solar zenith
!  angle over a 24 hour day, as well as the total length of daylight. 
!  This is needed to scale the offline OH and NO3 concentrations.
!  (rjp, bmy, 12/16/02, 12/8/04)
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE OHNO3TIME
!! 
! !USES:
      ! References to F90 modules
      USE GRID_MOD, ONLY : GET_XMID,    GET_YMID_R
      USE TIME_MOD, ONLY : GET_NHMSb,   GET_ELAPSED_SEC
      USE TIME_MOD, ONLY : GET_TS_CHEM, GET_DAY_OF_YEAR, GET_GMT


#     include "CMN_SIZE"  ! Size parameters
#     include "CMN_GCTM"  ! Physical constants
! !INPUT PARAMETERS: 
!
!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version for POPS_MOD
!
! !REMARKS:
!  (1 ) Copy code from COSSZA directly for now, so that we don't get NaN
!        values.  Figure this out later (rjp, bmy, 1/10/03)
!  (2 ) Now replace XMID(I) with routine GET_XMID from "grid_mod.f".  
!        Now replace RLAT(J) with routine GET_YMID_R from "grid_mod.f". 
!        Removed NTIME, NHMSb from the arg list.  Now use GET_NHMSb,
!        GET_ELAPSED_SEC, GET_TS_CHEM, GET_DAY_OF_YEAR, GET_GMT from 
!        "time_mod.f". (bmy, 3/27/03)
!  (3 ) Now store the peak SUNCOS value for each surface grid box (I,J) in 
!        the COSZM array. (rjp, bmy, 3/30/04)
!  (4 ) Also added parallel loop over grid boxes (eck, bmy, 12/8/04)
!  (5 ) copied from mercury_mod by eck (9/20/10)
!******************************************************************************
!
!EOP
!------------------------------------------------------------------------------
!BOC
      ! Local variables
      LOGICAL, SAVE       :: FIRST = .TRUE.
      INTEGER             :: I, IJLOOP, J, L, N, NT, NDYSTEP
      REAL*8              :: A0, A1, A2, A3, B1, B2, B3
      REAL*8              :: LHR0, R, AHR, DEC, TIMLOC, YMID_R
      REAL*8              :: SUNTMP(MAXIJ)
      
      !=================================================================
      ! OHNO3TIME begins here!
      !=================================================================

      !  Solar declination angle (low precision formula, good enough for us):
      A0 = 0.006918
      A1 = 0.399912
      A2 = 0.006758
      A3 = 0.002697
      B1 = 0.070257
      B2 = 0.000907
      B3 = 0.000148
      R  = 2.* PI * float( GET_DAY_OF_YEAR() - 1 ) / 365.

      DEC = A0 - A1*cos(  R) + B1*sin(  R)
     &         - A2*cos(2*R) + B2*sin(2*R)
     &         - A3*cos(3*R) + B3*sin(3*R)

      LHR0 = int(float( GET_NHMSb() )/10000.)

      ! Only do the following at the start of a new day
      IF ( FIRST .or. GET_GMT() < 1e-5 ) THEN 
      
         ! Zero arrays
         TTDAY(:,:) = 0d0
         TCOSZ(:,:) = 0d0
         COSZM(:,:) = 0d0

         ! NDYSTEP is # of chemistry time steps in this day
         NDYSTEP = ( 24 - INT( GET_GMT() ) ) * 60 / GET_TS_CHEM()         

         ! NT is the elapsed time [s] since the beginning of the run
         NT = GET_ELAPSED_SEC()

         ! Loop forward through NDYSTEP "fake" timesteps for this day 
         DO N = 1, NDYSTEP
            
            ! Zero SUNTMP array
            SUNTMP(:) = 0d0

            ! Loop over surface grid boxes
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, YMID_R, IJLOOP, TIMLOC, AHR )
            DO J = 1, JJPAR

               ! Grid box latitude center [radians]
               YMID_R = GET_YMID_R( J )

            DO I = 1, IIPAR

               ! Increment IJLOOP
               IJLOOP = ( (J-1) * IIPAR ) + I
               TIMLOC = real(LHR0) + real(NT)/3600.0 + GET_XMID(I)/15.0
         
               DO WHILE (TIMLOC .lt. 0)
                  TIMLOC = TIMLOC + 24.0
               ENDDO

               DO WHILE (TIMLOC .gt. 24.0)
                  TIMLOC = TIMLOC - 24.0
               ENDDO

               AHR = abs(TIMLOC - 12.) * 15.0 * PI_180

            !===========================================================
            ! The cosine of the solar zenith angle (SZA) is given by:
            !     
            !  cos(SZA) = sin(LAT)*sin(DEC) + cos(LAT)*cos(DEC)*cos(AHR) 
            !                   
            ! where LAT = the latitude angle, 
            !       DEC = the solar declination angle,  
            !       AHR = the hour angle, all in radians. 
            !
            ! If SUNCOS < 0, then the sun is below the horizon, and 
            ! therefore does not contribute to any solar heating.  
            !===========================================================

               ! Compute Cos(SZA)
               SUNTMP(IJLOOP) = sin(YMID_R) * sin(DEC) +
     &                          cos(YMID_R) * cos(DEC) * cos(AHR)

               ! TCOSZ is the sum of SUNTMP at location (I,J)
               ! Do not include negative values of SUNTMP
               TCOSZ(I,J) = TCOSZ(I,J) + MAX( SUNTMP(IJLOOP), 0d0 )

               ! COSZM is the peak value of SUMTMP during a day at (I,J)
               ! (rjp, bmy, 3/30/04)
               COSZM(I,J) = MAX( COSZM(I,J), SUNTMP(IJLOOP) )

               ! TTDAY is the total daylight time at location (I,J)
               IF ( SUNTMP(IJLOOP) > 0d0 ) THEN
                  TTDAY(I,J) = TTDAY(I,J) + DBLE( GET_TS_CHEM() )
               ENDIF
            ENDDO
            ENDDO
!$OMP END PARALLEL DO

            ! Increment elapsed time [sec]
            NT = NT + ( GET_TS_CHEM() * 60 )             
         ENDDO

         ! Reset first-time flag
         FIRST = .FALSE.
      ENDIF

      ! Return to calling program
      END SUBROUTINE OHNO3TIME

!EOC
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  INIT_POPS
!
! !DESCRIPTION: Subroutine INIT_POPS allocates and zeroes all module arrays.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE INIT_POPS
!
      ! References to F90 modules
      USE DRYDEP_MOD,   ONLY : DEPNAME,   NUMDEP
      USE ERROR_MOD,    ONLY : ALLOC_ERR, ERROR_STOP
      USE LOGICAL_MOD,  ONLY : LSPLIT,    LDRYD,     LNLPBL
      USE TRACER_MOD,   ONLY : N_TRACERS
      USE PBL_MIX_MOD,  ONLY : GET_PBL_MAX_L
c$$$
#     include "CMN_SIZE"     ! Size parameters
#     include "CMN_DIAG"     ! ND44

! !INPUT PARAMETERS: 
!
!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version
!
! !REMARKS:
! (1) Based initially on INIT_MERCURY from MERCURY_MOD (eck, 9/20/10)
!
!EOP
!------------------------------------------------------------------------------
!BOC

      ! Local variables
      LOGICAL, SAVE         :: IS_INIT = .FALSE. 
      INTEGER               :: AS, N!, PBL_MAX
      REAL*8                :: MAX_A, MIN_A
      !=================================================================
      ! INIT_POPS begins here!
      !=================================================================

      ! Maximum extent of the PBL
      !PBL_MAX = GET_PBL_MAX_L()

      ! Return if we have already allocated arrays
      IF ( IS_INIT ) RETURN

      !=================================================================
      ! Allocate and initialize arrays
      !=================================================================
      ALLOCATE( COSZM( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'COSZM' )
      COSZM = 0d0

      ALLOCATE( TCOSZ( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'TCOSZ' )
      TCOSZ = 0d0

      ALLOCATE( TTDAY( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'TTDAY' )
      TTDAY = 0d0

      ALLOCATE( C_OC( IIPAR, JJPAR, LLPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'C_OC' )
      C_OC = 0d0

      ALLOCATE( C_BC( IIPAR, JJPAR, LLPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'C_BC' )
      C_BC = 0d0

      ALLOCATE( SUM_OC_EM( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'SUM_OC_EM' )
      SUM_OC_EM = 0d0

      ALLOCATE( SUM_BC_EM( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'SUM_BC_EM' )
      SUM_BC_EM = 0d0

      ALLOCATE( SUM_G_EM( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'SUM_G_EM' )
      SUM_G_EM = 0d0

      ALLOCATE( SUM_OF_ALL( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'SUM_OF_ALL' )
      SUM_OF_ALL = 0d0

      ALLOCATE( EPOP_G( IIPAR, JJPAR, LLPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'EPOP_G' )
      EPOP_G = 0d0

      ALLOCATE( EPOP_OC( IIPAR, JJPAR, LLPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'EPOP_OC' )
      EPOP_OC = 0d0

      ALLOCATE( EPOP_BC( IIPAR, JJPAR, LLPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'EPOP_BC' )
      EPOP_BC = 0d0

      ALLOCATE( EPOP_P_TOT( IIPAR, JJPAR, LLPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'EPOP_P_TOT' )
      EPOP_P_TOT = 0d0

      ALLOCATE( POP_TOT_EM( IIPAR, JJPAR ), STAT=AS )
      IF ( AS /= 0 ) CALL ALLOC_ERR( 'POP_TOT_EM' )
      POP_TOT_EM = 0d0

      ! Allocate ZERO_DVEL if we use non-local PBL mixing or
      ! if drydep is turned off 
      IF ( LNLPBL .OR. (.not. LDRYD) ) THEN
         ALLOCATE( ZERO_DVEL( IIPAR, JJPAR ), STAT=AS )
         IF ( AS /= 0 ) CALL ALLOC_ERR( 'ZERO_DVEL' )
         ZERO_DVEL = 0d0
      ENDIF

      !=================================================================
      ! Done
      !=================================================================

      ! Reset IS_INIT, since we have already allocated arrays
      IS_INIT = .TRUE.
      
      ! Return to calling program
      END SUBROUTINE INIT_POPS

!EOC
!------------------------------------------------------------------------------
!------------------------------------------------------------------------------
!          Harvard University Atmospheric Chemistry Modeling Group            
!------------------------------------------------------------------------------
!BOP
!
! !IROUTINE:  CLEANUP_POPS
!
! !DESCRIPTION: Subroutine CLEANUP_POPS deallocates all module arrays.
!\\
!\\
! !INTERFACE:
!
      SUBROUTINE CLEANUP_POPS
!

! !INPUT PARAMETERS: 
!
!
! !INPUT/OUTPUT PARAMETERS: 
!
!
! !OUTPUT PARAMETERS:
!
!
! !REVISION HISTORY: 
!  20 September 2010 - N.E. Selin - Initial Version
!
! !REMARKS:
! (1) Based initially on INIT_MERCURY from MERCURY_MOD (eck, 9/20/10)
!
!EOP
!------------------------------------------------------------------------------
!BOC

      IF ( ALLOCATED( COSZM     ) ) DEALLOCATE( COSZM   )     
      IF ( ALLOCATED( TCOSZ     ) ) DEALLOCATE( TCOSZ   )
      IF ( ALLOCATED( TTDAY     ) ) DEALLOCATE( TTDAY   )
      IF ( ALLOCATED( ZERO_DVEL ) ) DEALLOCATE( ZERO_DVEL )
      IF ( ALLOCATED( EPOP_G    ) ) DEALLOCATE( EPOP_G   )
      IF ( ALLOCATED( EPOP_OC   ) ) DEALLOCATE( EPOP_OC  )
      IF ( ALLOCATED( EPOP_BC   ) ) DEALLOCATE( EPOP_BC )
      IF ( ALLOCATED( EPOP_P_TOT) ) DEALLOCATE( EPOP_P_TOT )
      IF ( ALLOCATED( POP_TOT_EM) ) DEALLOCATE( POP_TOT_EM )
      IF ( ALLOCATED( C_OC      ) ) DEALLOCATE( C_OC )
      IF ( ALLOCATED( C_BC      ) ) DEALLOCATE( C_BC )
      IF ( ALLOCATED( SUM_OC_EM  ) ) DEALLOCATE( SUM_OC_EM )
      IF ( ALLOCATED( SUM_BC_EM  ) ) DEALLOCATE( SUM_BC_EM )
      IF ( ALLOCATED( SUM_G_EM   ) ) DEALLOCATE( SUM_G_EM ) 
      IF ( ALLOCATED( SUM_OF_ALL ) ) DEALLOCATE( SUM_OF_ALL ) 

      END SUBROUTINE CLEANUP_POPS
!EOC
!------------------------------------------------------------------------------
      END MODULE POPS_MOD

