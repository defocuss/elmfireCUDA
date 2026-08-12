! *****************************************************************************
MODULE ELMFIRE_SUBS
! *****************************************************************************

USE ELMFIRE_VARS
USE MPI_F08

IMPLICIT NONE

CONTAINS

! *****************************************************************************
SUBROUTINE WRITE_TIMINGS_TO_DISK
! *****************************************************************************

INTEGER :: I,IOS,IR,LU
CHARACTER(400) :: FN

LU=3939

FN = TRIM(OUTPUTS_DIRECTORY) // 'timings_' // TRIM(PROCNAME) // '.csv'  
OPEN(LU,FILE=TRIM(FN),FORM='FORMATTED',STATUS='REPLACE',IOSTAT=IOS)
WRITE(LU,100) '#,', (IR, IR=0, NPROC_HOST-1)
DO I = 1, 62
   WRITE(LU,300) I, (TIMINGS(IR+1,I), IR=0, NPROC_HOST-1)
ENDDO
CLOSE(LU)

100 FORMAT (A,128(I3,','))
300 FORMAT (I3,',',128(F11.5,','))

! *****************************************************************************
END SUBROUTINE WRITE_TIMINGS_TO_DISK
! *****************************************************************************

! *****************************************************************************
SUBROUTINE ACCUMULATE_CPU_USAGE(IBLOCK,IT1,IT2)
! *****************************************************************************

INTEGER, INTENT(IN) :: IBLOCK
INTEGER, INTENT(INOUT) :: IT1
INTEGER :: IT2

CALL SYSTEM_CLOCK(IT2)
TIMINGS(IRANK_HOST+1,IBLOCK) = TIMINGS(IRANK_HOST+1,IBLOCK) + REAL(IT2 - IT1) / REAL(CLOCK_COUNT_RATE)
CALL SYSTEM_CLOCK(IT1)

! *****************************************************************************
END SUBROUTINE ACCUMULATE_CPU_USAGE
! *****************************************************************************

! *****************************************************************************
SUBROUTINE MPI_BCAST_RASTER_HEADER(R, IROOT, JUST_SEND_SIZE)
! *****************************************************************************

TYPE (RASTER_TYPE) :: R
INTEGER, INTENT(IN) :: IROOT
LOGICAL, INTENT(IN) :: JUST_SEND_SIZE
INTEGER :: IERR

IF (JUST_SEND_SIZE) THEN
   CALL MPI_BCAST(R%NROWS         ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NCOLS         ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NBANDS        ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
ELSE
   CALL MPI_BCAST(R%BYTEORDER     ,  1, MPI_CHARACTER  , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%LAYOUT        ,  3, MPI_CHARACTER  , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NROWS         ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NCOLS         ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NBANDS        ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NBITS         ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%BANDROWBYTES  ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%TOTALROWBYTES ,  1, MPI_INTEGER    , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%PIXELTYPE     , 10, MPI_CHARACTER  , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%ULXMAP        ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%ULYMAP        ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%XDIM          ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%YDIM          ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%NODATA_VALUE  ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%CELLSIZE      ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%XLLCORNER     ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
   CALL MPI_BCAST(R%YLLCORNER     ,  1, MPI_REAL       , IROOT, MPI_COMM_WORLD, IERR)
ENDIF

! *****************************************************************************
END SUBROUTINE MPI_BCAST_RASTER_HEADER
! *****************************************************************************

! *****************************************************************************
SUBROUTINE BCAST_WEATHER_FUEL_TOPOGRAPHY
! *****************************************************************************

INTEGER :: IERR, FUEL_TOPO_COUNT, WEATHER_COUNT

FUEL_TOPO_COUNT = ASP%NCOLS * ASP%NROWS
WEATHER_COUNT= WS%NCOLS * WS%NROWS * WS%NBANDS

CALL MPI_BCAST(WS%R4  , WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(WD%R4  , WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(M1%R4  , WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(M10%R4 , WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(M100%R4, WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(MLH%R4 , WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(MLW%R4 , WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(MFOL%R4, WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

IF (USE_ERC) THEN
   CALL MPI_BCAST(ERC%R4, WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
   CALL MPI_BCAST(IGNFAC%R4, WEATHER_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
ENDIF

IF (USE_IGNITION_MASK) CALL MPI_BCAST(IGN_MASK%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

CALL MPI_BCAST(ASP%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(CBH%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(CBD%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(CC%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(CH%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

IF (MODE .NE. 2) CALL MPI_BCAST(DEM%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

CALL MPI_BCAST(FBFM%I2, FUEL_TOPO_COUNT, MPI_SHORT, 0, MPI_COMM_HOST_IRANK0, IERR)

CALL MPI_BCAST(SLP%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(ADJ%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

IF (MODE .NE. 2) CALL MPI_BCAST(PHI0%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

CALL MPI_BCAST(WAF%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
CALL MPI_BCAST(OMCOSSLPRAD%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)

CALL MPI_BCAST(ISNONBURNABLE, FUEL_TOPO_COUNT, MPI_BYTE, 0, MPI_COMM_HOST_IRANK0, IERR)

IF (USE_POPULATION_DENSITY) CALL MPI_BCAST(POPULATION_DENSITY%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
IF (USE_REAL_ESTATE_VALUE ) CALL MPI_BCAST(REAL_ESTATE_VALUE%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
IF (USE_LAND_VALUE        ) CALL MPI_BCAST(LAND_VALUE%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
IF (USE_SDI               ) CALL MPI_BCAST(SDI%R4, FUEL_TOPO_COUNT, MPI_REAL, 0, MPI_COMM_HOST_IRANK0, IERR)
IF (USE_BLDG_SPREAD_MODEL) THEN
   CALL MPI_BCAST(BLDG_AREA%R4            , FUEL_TOPO_COUNT, MPI_REAL , 0, MPI_COMM_HOST_IRANK0, IERR)
   CALL MPI_BCAST(BLDG_SEPARATION_DIST%R4 , FUEL_TOPO_COUNT, MPI_REAL , 0, MPI_COMM_HOST_IRANK0, IERR)
   CALL MPI_BCAST(BLDG_NONBURNABLE_FRAC%R4, FUEL_TOPO_COUNT, MPI_REAL , 0, MPI_COMM_HOST_IRANK0, IERR)
   CALL MPI_BCAST(BLDG_FOOTPRINT_FRAC%R4  , FUEL_TOPO_COUNT, MPI_REAL , 0, MPI_COMM_HOST_IRANK0, IERR)
   CALL MPI_BCAST(BLDG_FUEL_MODEL%I2      , FUEL_TOPO_COUNT, MPI_SHORT, 0, MPI_COMM_HOST_IRANK0, IERR)
ENDIF

IF (USE_PYROMES) CALL MPI_BCAST(PYROMES%I2, FUEL_TOPO_COUNT, MPI_SHORT, 0, MPI_COMM_HOST_IRANK0, IERR)

! *****************************************************************************
END SUBROUTINE BCAST_WEATHER_FUEL_TOPOGRAPHY
! *****************************************************************************

! *****************************************************************************
SUBROUTINE PERTURB_RASTERS(R1)
! *****************************************************************************

REAL, INTENT(IN), DIMENSION(:) :: R1

INTEGER :: I

DO I = 1, NUM_RASTERS_TO_PERTURB
   COEFFS_UNSCALED(I) = PDF_LOWER_LIMIT(I) + R1(I) * (PDF_UPPER_LIMIT(I) - PDF_LOWER_LIMIT(I))
   SELECT CASE (TRIM(RASTER_TO_PERTURB(I)))
      CASE('ADJ')
         PERTURB_ADJ  = COEFFS_UNSCALED(I)
      CASE('CBD')
         PERTURB_CBD  = COEFFS_UNSCALED(I)
      CASE('CBH')
         PERTURB_CBH  = COEFFS_UNSCALED(I)
      CASE('FMC')
         PERTURB_FMC  = COEFFS_UNSCALED(I)
      CASE('M1')
         PERTURB_M1   = COEFFS_UNSCALED(I)
      CASE('M10')
         PERTURB_M10  = COEFFS_UNSCALED(I)
      CASE('M100')
         PERTURB_M100 = COEFFS_UNSCALED(I)
      CASE('MLH')
         PERTURB_MLH  = COEFFS_UNSCALED(I)
      CASE('MLW')
         PERTURB_MLW  = COEFFS_UNSCALED(I)
      CASE('WAF')
         PERTURB_WAF  = COEFFS_UNSCALED(I)
      CASE('WD')
         PERTURB_WD   = COEFFS_UNSCALED(I)
      CASE('WS')
         PERTURB_WS   = COEFFS_UNSCALED(I)
   END SELECT

ENDDO

! *****************************************************************************
END SUBROUTINE PERTURB_RASTERS
! *****************************************************************************

! *****************************************************************************
SUBROUTINE GET_OPERATING_SYSTEM
! *****************************************************************************

CHARACTER(2000) :: PATH

CALL GET_ENVIRONMENT_VARIABLE('PATH',PATH)

IF (PATH(1:1) .EQ. '/') THEN 
   OPERATING_SYSTEM = 'linux  '
   PATH_SEPARATOR   = '/'
   DELETECOMMAND    = '/bin/rm -f '
ELSE
   OPERATING_SYSTEM = 'windows'
   PATH_SEPARATOR   = '\'
   DELETECOMMAND    = 'del   '
ENDIF

! *****************************************************************************
END SUBROUTINE GET_OPERATING_SYSTEM
! *****************************************************************************

! *****************************************************************************
SUBROUTINE ALLOCATE_EMPTY_RASTER(RASTER,NCOLS,NROWS,NBANDS,XLLCORNER,YLLCORNER,CELLSIZE,NODATA_VALUE,PIXELTYPE)
! *****************************************************************************

TYPE(RASTER_TYPE), INTENT(INOUT) :: RASTER
INTEGER, INTENT(IN) :: NCOLS, NROWS, NBANDS
REAL, INTENT(IN) :: XLLCORNER, YLLCORNER, CELLSIZE, NODATA_VALUE
CHARACTER(10), INTENT(IN) :: PIXELTYPE
INTEGER :: NBITS

IF (TRIM(PIXELTYPE) .NE. 'FLOAT' .AND. TRIM(PIXELTYPE) .NE. 'SIGNEDINT' ) THEN
   WRITE(*,*) "Error in ALLOCATE_EMPTY_RASTER. For now, only available PIXELTYPE are 'FLOAT' and 'SIGNEDINT'."
   STOP
ENDIF

SELECT CASE(TRIM(PIXELTYPE))
   CASE('FLOAT')
      NBITS=32
   CASE('SIGNEDINT')
      NBITS=16
END SELECT

! Thse three variables are used by ELMFIRE but are not in the BIL header:
RASTER%XLLCORNER    = XLLCORNER
RASTER%YLLCORNER    = YLLCORNER
RASTER%CELLSIZE     = CELLSIZE

! These variables, in order, get written to the BIL header
RASTER%BYTEORDER     = 'I'
RASTER%LAYOUT        = 'BIL'
RASTER%NROWS         = NROWS
RASTER%NCOLS         = NCOLS
RASTER%NBANDS        = NBANDS
RASTER%NBITS         = NBITS
RASTER%BANDROWBYTES  = (RASTER%NBITS/8) * RASTER%NCOLS
RASTER%TOTALROWBYTES = RASTER%BANDROWBYTES * RASTER%NBANDS
RASTER%PIXELTYPE     = PIXELTYPE
RASTER%ULXMAP        = RASTER%XLLCORNER + 0.5*RASTER%CELLSIZE
RASTER%ULYMAP        = RASTER%YLLCORNER - 0.5*RASTER%CELLSIZE + REAL(RASTER%NROWS)*RASTER%CELLSIZE
RASTER%XDIM          = RASTER%CELLSIZE
RASTER%YDIM          = RASTER%CELLSIZE
RASTER%NODATA_VALUE  = NODATA_VALUE
 
SELECT CASE(TRIM(PIXELTYPE))
   CASE('FLOAT')
      ALLOCATE(RASTER%R4(1:NCOLS,1:NROWS,1:NBANDS))
      RASTER%R4(:,:,:) = NODATA_VALUE
   CASE('SIGNEDINT')
      ALLOCATE(RASTER%I2(1:NCOLS,1:NROWS,1:NBANDS))
      RASTER%I2(:,:,:) = NINT(NODATA_VALUE,2)
   CASE DEFAULT
      CONTINUE
END SELECT

! *****************************************************************************
END SUBROUTINE ALLOCATE_EMPTY_RASTER
! *****************************************************************************

! *****************************************************************************
SUBROUTINE MAP_FINE_TO_COARSE(COARSE,FINE,ICOL_COARSE,IROW_COARSE)
! *****************************************************************************

TYPE(RASTER_TYPE), INTENT(IN) :: COARSE, FINE
INTEGER, DIMENSION(:), INTENT(OUT) :: ICOL_COARSE, IROW_COARSE !fine to coarse

INTEGER :: ICOL, IROW
REAL, ALLOCATABLE, DIMENSION (:) :: X, Y

ALLOCATE(X(1:FINE%NCOLS))
ALLOCATE(Y(1:FINE%NROWS))

DO ICOL = 1, FINE%NCOLS
   X(ICOL) = FINE%XLLCORNER + (REAL(ICOL) - 0.5) * FINE%CELLSIZE
ENDDO

DO IROW = 1, FINE%NROWS
   Y(IROW) = FINE%YLLCORNER + (REAL(IROW) - 0.5) * FINE%CELLSIZE
ENDDO

ICOL_COARSE(:) = MIN(MAX(CEILING( (X(:) - COARSE%XLLCORNER) / COARSE%CELLSIZE),1),COARSE%NCOLS)
IROW_COARSE(:) = MIN(MAX(CEILING( (Y(:) - COARSE%YLLCORNER) / COARSE%CELLSIZE),1),COARSE%NROWS)

DEALLOCATE(X)
DEALLOCATE(Y)

! *****************************************************************************
END SUBROUTINE MAP_FINE_TO_COARSE
! *****************************************************************************

! *****************************************************************************
INTEGER FUNCTION ICOL_FROM_X(X,XLL,CELLSIZE)
! *****************************************************************************

REAL, INTENT(IN) :: X,XLL,CELLSIZE
REAL :: DIST

DIST = X - XLL 

ICOL_FROM_X = CEILING(DIST / CELLSIZE)

! *****************************************************************************
END FUNCTION ICOL_FROM_X
! *****************************************************************************

! *****************************************************************************
INTEGER FUNCTION IROW_FROM_Y(Y,YLL,CELLSIZE)
! *****************************************************************************

REAL, INTENT(IN) :: Y,YLL,CELLSIZE
REAL :: DIST

DIST = Y - YLL 

IROW_FROM_Y = CEILING(DIST / CELLSIZE)

! *****************************************************************************
END FUNCTION IROW_FROM_Y
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION X_FROM_ICOL(ICOL,XLL,CELLSIZE)
! *****************************************************************************

INTEGER, INTENT(IN) :: ICOL
REAL, INTENT(IN) :: XLL, CELLSIZE

X_FROM_ICOL = XLL + (REAL(ICOL)-0.5) * CELLSIZE 

! *****************************************************************************
END FUNCTION X_FROM_ICOL
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION Y_FROM_IROW(IROW,YLL,CELLSIZE)
! *****************************************************************************

INTEGER, INTENT(IN) :: IROW
REAL, INTENT(IN) :: YLL, CELLSIZE

Y_FROM_IROW = YLL + (REAL(IROW)-0.5) * CELLSIZE 

! *****************************************************************************
END FUNCTION Y_FROM_IROW
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WD_RASTER(L,WD_LO,WD_HI,F)
! *****************************************************************************

TYPE (DLL), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN) :: WD_LO, WD_HI
REAL, INTENT(IN) :: F
INTEGER :: I, ICOL, IROW
REAL :: WD1TO, WD2TO, WDTO
TYPE(NODE), POINTER :: C

C => L%HEAD
DO I = 1, L%NUM_NODES
   ICOL = ICOL_ANALYSIS_F2C(C%IX)
   IROW = IROW_ANALYSIS_F2C(C%IY)
   WD1TO = WD_LO(ICOL,IROW) + 180. ; IF (WD1TO .GT. 360) WD1TO = WD1TO - 360.
   WD2TO = WD_HI(ICOL,IROW) + 180. ; IF (WD2TO .GT. 360) WD2TO = WD2TO - 360.
   WDTO = WD1TO + F * (WD2TO - WD1TO)
   C%WD20_INTERP = WDTO + 180. + PERTURB_WD
   IF (C%WD20_INTERP .GT. 360.) C%WD20_INTERP = C%WD20_INTERP - 360.
   IF (C%WD20_INTERP .LT.   0.) C%WD20_INTERP = C%WD20_INTERP + 360.
   C%WD20_NOW = C%WD20_INTERP
   C => C%NEXT
ENDDO
  
! *****************************************************************************
END SUBROUTINE INTERP_WD_RASTER
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WD_RASTER_NL(L,WD_LO,WD_HI,F) ! List of nodes version of INTERP_WD_RASTER
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN) :: WD_LO, WD_HI
REAL, INTENT(IN) :: F
INTEGER :: I, ICOL, IROW
REAL :: WD1TO, WD2TO, WDTO
!TYPE(NODE), POINTER :: C

!C => L%HEAD
DO I = 1, L%NUM_NODES
   ICOL = ICOL_ANALYSIS_F2C(L%IX(I))
   IROW = IROW_ANALYSIS_F2C(L%IY(I))
   WD1TO = WD_LO(ICOL,IROW) + 180. ; IF (WD1TO .GT. 360) WD1TO = WD1TO - 360.
   WD2TO = WD_HI(ICOL,IROW) + 180. ; IF (WD2TO .GT. 360) WD2TO = WD2TO - 360.
   WDTO = WD1TO + F * (WD2TO - WD1TO)
   L%WD20_INTERP(I) = WDTO + 180. + PERTURB_WD
   IF (L%WD20_INTERP(I) .GT. 360.) L%WD20_INTERP(I) = L%WD20_INTERP(I) - 360.
   IF (L%WD20_INTERP(I) .LT.   0.) L%WD20_INTERP(I) = L%WD20_INTERP(I) + 360.
   L%WD20_NOW(I) = L%WD20_INTERP(I)
   !C => C%NEXT
ENDDO
  
! *****************************************************************************
END SUBROUTINE INTERP_WD_RASTER_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WD_RASTER_SINGLE_NL(NL,NODE_INDEX,WD_LO,WD_HI,F) ! List of nodes version of INTERP_WD_RASTER_SINGLE
! *****************************************************************************

TYPE(NODE_LIST), INTENT(INOUT) :: NL
REAL, DIMENSION(:,:), INTENT(IN) :: WD_LO, WD_HI
REAL, INTENT(IN) :: F
INTEGER :: ICOL, IROW, NODE_INDEX
REAL :: WD1TO, WD2TO, WDTO
!TYPE(NODE), POINTER :: C

!C => NODEIN

ICOL = ICOL_ANALYSIS_F2C(NL%IX(NODE_INDEX))
IROW = IROW_ANALYSIS_F2C(NL%IY(NODE_INDEX))
WD1TO = WD_LO(ICOL,IROW) + 180. ; IF (WD1TO .GT. 360) WD1TO = WD1TO - 360.
WD2TO = WD_HI(ICOL,IROW) + 180. ; IF (WD2TO .GT. 360) WD2TO = WD2TO - 360.
WDTO = WD1TO + F * (WD2TO - WD1TO)
NL%WD20_INTERP(NODE_INDEX) = WDTO + 180. + PERTURB_WD
IF (NL%WD20_INTERP(NODE_INDEX) .GT. 360.) NL%WD20_INTERP(NODE_INDEX) = NL%WD20_INTERP(NODE_INDEX) - 360.
IF (NL%WD20_INTERP(NODE_INDEX) .LT.   0.) NL%WD20_INTERP(NODE_INDEX) = NL%WD20_INTERP(NODE_INDEX) + 360.

NL%WD20_NOW(NODE_INDEX) = NL%WD20_INTERP(NODE_INDEX)
  
! *****************************************************************************
END SUBROUTINE INTERP_WD_RASTER_SINGLE_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WD_RASTER_SINGLE(NODEIN,WD_LO,WD_HI,F)
! *****************************************************************************

TYPE(NODE), POINTER, INTENT(OUT) :: NODEIN
REAL, DIMENSION(:,:), INTENT(IN) :: WD_LO, WD_HI
REAL, INTENT(IN) :: F
INTEGER :: ICOL, IROW
REAL :: WD1TO, WD2TO, WDTO
TYPE(NODE), POINTER :: C

C => NODEIN

ICOL = ICOL_ANALYSIS_F2C(C%IX)
IROW = IROW_ANALYSIS_F2C(C%IY)
WD1TO = WD_LO(ICOL,IROW) + 180. ; IF (WD1TO .GT. 360) WD1TO = WD1TO - 360.
WD2TO = WD_HI(ICOL,IROW) + 180. ; IF (WD2TO .GT. 360) WD2TO = WD2TO - 360.
WDTO = WD1TO + F * (WD2TO - WD1TO)
C%WD20_INTERP = WDTO + 180. + PERTURB_WD
IF (C%WD20_INTERP .GT. 360.) C%WD20_INTERP = C%WD20_INTERP - 360.
IF (C%WD20_INTERP .LT.   0.) C%WD20_INTERP = C%WD20_INTERP + 360.

C%WD20_NOW = C%WD20_INTERP
  
! *****************************************************************************
END SUBROUTINE INTERP_WD_RASTER_SINGLE
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST(L,LO,HI,F,IQUANTITY)
! *****************************************************************************

TYPE (DLL), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN ) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
INTEGER :: I,ICOL,IROW
TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.

C => L%HEAD

SELECT CASE (IQUANTITY)

   CASE (1)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%M1 = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%M1 = MAX (C%M1 + PERTURB_M1, 0.01)
         C => C%NEXT
      ENDDO

   CASE (2)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%M10 = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%M10 = MAX (C%M10 + PERTURB_M10, 0.01)
         C => C%NEXT
      ENDDO

   CASE (3)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%M100 = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%M100 = MAX (C%M100 + PERTURB_M100, 0.01)
         C => C%NEXT
      ENDDO

   CASE (4)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%MLH = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%MLH = MAX(C%MLH + PERTURB_MLH, 0.3)
         C => C%NEXT
      ENDDO

   CASE (5)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%MLW = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%MLW = MAX(C%MLW + PERTURB_MLW, 0.6)
         C => C%NEXT
      ENDDO

   CASE (6)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%FMC = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%FMC = C%FMC + PERTURB_FMC
         C => C%NEXT
      ENDDO

   CASE (7)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(C%IX)
         IROW = WX_IROW_FROM_ANALYSIS_IY(C%IY)
         C%WS20_INTERP = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         C%WS20_INTERP = MAX(C%WS20_INTERP + PERTURB_WS, 0.0)
         C%WS20_NOW = C%WS20_INTERP
         C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
         C => C%NEXT
      ENDDO

END SELECT

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_NODE_LIST(L,LO,HI,F,IQUANTITY) ! List of node version of INTERP_RASTER_LINKEDLIST
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN ) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
INTEGER :: I,ICOL,IROW
!TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.

!C => L%HEAD

SELECT CASE (IQUANTITY)

   CASE (1)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%M1(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%M1(I) = MAX (L%M1(I) + PERTURB_M1, 0.01)
         !C => C%NEXT
      ENDDO

   CASE (2)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%M10(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%M10(I) = MAX (L%M10(I) + PERTURB_M10, 0.01)
         !C => C%NEXT
      ENDDO

   CASE (3)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%M100(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%M100(I) = MAX (L%M100(I) + PERTURB_M100, 0.01)
         !C => C%NEXT
      ENDDO

   CASE (4)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%MLH(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%MLH(I) = MAX(L%MLH(I) + PERTURB_MLH, 0.3)
         !C => C%NEXT
      ENDDO

   CASE (5)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%MLW(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%MLW(I) = MAX(L%MLW(I) + PERTURB_MLW, 0.6)
         !C => C%NEXT
      ENDDO

   CASE (6)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%FMC(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%FMC(I) = L%FMC(I) + PERTURB_FMC
         !C => C%NEXT
      ENDDO

   CASE (7)
      DO I = 1, L%NUM_NODES
         ICOL = WX_ICOL_FROM_ANALYSIS_IX(L%IX(I))
         IROW = WX_IROW_FROM_ANALYSIS_IY(L%IY(I))
         L%WS20_INTERP(I) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
         L%WS20_INTERP(I) = MAX(L%WS20_INTERP(I) + PERTURB_WS, 0.0)
         L%WS20_NOW(I) = L%WS20_INTERP(I)
         L%WSMF(I) = L%WS20_NOW(I) * MAX((WAF%R4(L%IX(I),L%IY(I),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
         !C => C%NEXT
      ENDDO

END SELECT

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_NODE_LIST
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST_BILINEAR_NL(L,LO,HI,F,IQUANTITY) ! List of nodes version of INTERP_RASTER_LINKEDLIST_BILINEAR
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
!TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY, PL, PH, PNOW
REAL :: Q11L, Q21L, Q12L, Q22L, Q11H, Q21H, Q12H, Q22H
INTEGER :: I, I1, I2, J1, J2

!C => L%HEAD

DO I = 1, L%NUM_NODES
    
   CALL GET_BILINEAR_INTERPOLATE_COEFFS(L%IX(I), l%IY(I), X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

   Q12L = LO(I1, J2) ; Q22L = LO(I2, J2)
   Q11L = LO(I1, J1) ; Q21L = LO(I2, J1)
   PL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11L, Q21L, Q12L, Q22L)
         
   Q12H = HI(I1, J2) ; Q22H = HI(I2, J2)
   Q11H = HI(I1, J1) ; Q21H = HI(I2, J1)
   PH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11H, Q21H, Q12H, Q22H)
   
   PNOW = PL + F * (PH - PL)

   SELECT CASE (IQUANTITY)
      CASE (1)
         L%M1(I)   = MAX (PNOW + PERTURB_M1  , 0.01)
      CASE (2)
         L%M10(I)  = MAX (PNOW + PERTURB_M10 , 0.01)
      CASE (3)
         L%M100(I) = MAX (PNOW + PERTURB_M100, 0.01)
      CASE (4)
         L%MLH(I)  = MAX (PNOW + PERTURB_MLH , 0.30)
      CASE (5)
         L%MLW(I)  = MAX (PNOW + PERTURB_MLW , 0.60)
      CASE (6)
         L%FMC(I) = PNOW + PERTURB_FMC
      CASE (7)
         L%WS20_INTERP(I) = MAX(PNOW + PERTURB_WS, 0.0)
         L%WS20_NOW(I) = L%WS20_INTERP(I)
         L%WSMF(I) = L%WS20_NOW(I) * MAX((WAF%R4(L%IX(I),L%IY(I),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
      END SELECT
   
   !C => C%NEXT

ENDDO

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST_BILINEAR_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST_BILINEAR(L,LO,HI,F,IQUANTITY)
! *****************************************************************************

TYPE (DLL), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY, PL, PH, PNOW
REAL :: Q11L, Q21L, Q12L, Q22L, Q11H, Q21H, Q12H, Q22H
INTEGER :: I, I1, I2, J1, J2

C => L%HEAD

DO I = 1, L%NUM_NODES
    
   CALL GET_BILINEAR_INTERPOLATE_COEFFS(C%IX, C%IY, X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

   Q12L = LO(I1, J2) ; Q22L = LO(I2, J2)
   Q11L = LO(I1, J1) ; Q21L = LO(I2, J1)
   PL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11L, Q21L, Q12L, Q22L)
         
   Q12H = HI(I1, J2) ; Q22H = HI(I2, J2)
   Q11H = HI(I1, J1) ; Q21H = HI(I2, J1)
   PH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11H, Q21H, Q12H, Q22H)
   
   PNOW = PL + F * (PH - PL)

   SELECT CASE (IQUANTITY)
      CASE (1)
         C%M1   = MAX (PNOW + PERTURB_M1  , 0.01)
      CASE (2)
         C%M10  = MAX (PNOW + PERTURB_M10 , 0.01)
      CASE (3)
         C%M100 = MAX (PNOW + PERTURB_M100, 0.01)
      CASE (4)
         C%MLH  = MAX (PNOW + PERTURB_MLH , 0.30)
      CASE (5)
         C%MLW  = MAX (PNOW + PERTURB_MLW , 0.60)
      CASE (6)
         C%FMC = PNOW + PERTURB_FMC
      CASE (7)
         C%WS20_INTERP = MAX(PNOW + PERTURB_WS, 0.0)
         C%WS20_NOW = C%WS20_INTERP
         C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
      END SELECT
   
   C => C%NEXT

ENDDO

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST_BILINEAR
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WIND_LINKEDLIST_BILINEAR(L,WSLO,WSHI,WDLO,WDHI,F)
! *****************************************************************************

TYPE (DLL), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN) :: WSLO,WSHI,WDLO,WDHI
REAL, INTENT(IN) :: F
TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY
REAL :: WS11L, WS21L, WS12L, WS22L, WS11H, WS21H, WS12H, WS22H, &
        WD11L, WD21L, WD12L, WD22L, WD11H, WD21H, WD12H, WD22H, &
        UX11L, UX21L, UX12L, UX22L, UX11H, UX21H, UX12H, UX22H, &
        UY11L, UY21L, UY12L, UY22L, UY11H, UY21H, UY12H, UY22H
REAL :: UXL, UXH, UYL, UYH, UXNOW, UYNOW, WSNOW, WDNOW

INTEGER :: I, I1, I2, J1, J2

C => L%HEAD

DO I = 1, L%NUM_NODES
    
   CALL GET_BILINEAR_INTERPOLATE_COEFFS(C%IX, C%IY, X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

! Wind speed and wind direction (lo)
   WS12L = WSLO(I1, J2) ; WS22L = WSLO(I2, J2)
   WS11L = WSLO(I1, J1) ; WS21L = WSLO(I2, J1)
   
   WD12L = WDLO(I1, J2) ; WD22L = WDLO(I2, J2)
   WD11L = WDLO(I1, J1) ; WD21L = WDLO(I2, J1)

! Convert to x and y components
   UX12L = UX_FROM_WSWD(WS12L, WD12L) ; UX22L = UX_FROM_WSWD(WS22L, WD22L)
   UX11L = UX_FROM_WSWD(WS11L, WD11L) ; UX21L = UX_FROM_WSWD(WS21L, WD21L)

   UY12L = UY_FROM_WSWD(WS12L, WD12L) ; UY22L = UY_FROM_WSWD(WS22L, WD22L)
   UY11L = UY_FROM_WSWD(WS11L, WD11L) ; UY21L = UY_FROM_WSWD(WS21L, WD21L)
   
! Interpolate spatially
   UXL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11L, UX21L, UX12L, UX22L)
   UYL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11L, UY21L, UY12L, UY22L)

! Wind speed and wind direction (hi)
   WS12H = WSHI(I1, J2) ; WS22H = WSHI(I2, J2)
   WS11H = WSHI(I1, J1) ; WS21H = WSHI(I2, J1)
   
   WD12H = WDHI(I1, J2) ; WD22H = WDHI(I2, J2)
   WD11H = WDHI(I1, J1) ; WD21H = WDHI(I2, J1)

! Convert to x and y components
   UX12H = UX_FROM_WSWD(WS12H, WD12H) ; UX22H = UX_FROM_WSWD(WS22H, WD22H)
   UX11H = UX_FROM_WSWD(WS11H, WD11H) ; UX21H = UX_FROM_WSWD(WS21H, WD21H)

   UY12H = UY_FROM_WSWD(WS12H, WD12H) ; UY22H = UY_FROM_WSWD(WS22H, WD22H)
   UY11H = UY_FROM_WSWD(WS11H, WD11H) ; UY21H = UY_FROM_WSWD(WS21H, WD21H)
   
! Interpolate spatially
   UXH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11H, UX21H, UX12H, UX22H)
   UYH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11H, UY21H, UY12H, UY22H)

! Interpolate temporally
   UXNOW = UXL + F * (UXH - UXL)
   UYNOW = UYL + F * (UYH - UYL)
   
! Convert to wind speed and direction
   IF      (UXNOW .EQ. 0. .AND. UYNOW .EQ. 0.) THEN 
      WDNOW = 0.
   ELSE IF (UXNOW .GT. 0. .AND. UYNOW .EQ. 0.) THEN
      WDNOW = 0.5*PI
   ELSE IF (UXNOW .LT. 0. .AND. UYNOW .EQ. 0.) THEN          
      WDNOW = 1.5*PI          
   ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .GT. 0.) THEN
      WDNOW = 0.0*PI
   ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .LT. 0.) THEN          
      WDNOW = 1.0*PI
   ELSE
      IF (UXNOW .GT. 0. .AND. UYNOW .GT. 0.) WDNOW = 0.     + ATAN(  UXNOW /  UYNOW ) 
      IF (UXNOW .GT. 0. .AND. UYNOW .LT. 0.) WDNOW = 0.5*PI + ATAN( -UYNOW /  UXNOW )
      IF (UXNOW .LT. 0. .AND. UYNOW .LT. 0.) WDNOW = PI     + ATAN(  UXNOW /  UYNOW )
      IF (UXNOW .LT. 0. .AND. UYNOW .GT. 0.) WDNOW = 1.5*PI + ATAN(  UYNOW / ABS(UXNOW) )
   ENDIF

   WSNOW = SQRT(UXNOW*UXNOW + UYNOW*UYNOW)
   
   WDNOW = WDNOW * 180. / PI
   WDNOW = WDNOW + 180. 
   IF (WDNOW .GT. 360) WDNOW = WDNOW - 360.

   C%WD20_INTERP = WDNOW + PERTURB_WD
   IF (C%WD20_INTERP .GT. 360.) C%WD20_INTERP = C%WD20_INTERP - 360.
   IF (C%WD20_INTERP .LT.   0.) C%WD20_INTERP = C%WD20_INTERP + 360.
   C%WD20_NOW = C%WD20_INTERP

   C%WS20_INTERP = MAX(WSNOW + PERTURB_WS, 0.0)
   C%WS20_NOW = C%WS20_INTERP
   C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
   
   C => C%NEXT

ENDDO

! *****************************************************************************
END SUBROUTINE INTERP_WIND_LINKEDLIST_BILINEAR
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WIND_LINKEDLIST_BILINEAR_NL(L,WSLO,WSHI,WDLO,WDHI,F) !List of node version of INTERP_WIND_LINKEDLIST_BILINEAR
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: L
REAL, DIMENSION(:,:), INTENT(IN) :: WSLO,WSHI,WDLO,WDHI
REAL, INTENT(IN) :: F
!TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY
REAL :: WS11L, WS21L, WS12L, WS22L, WS11H, WS21H, WS12H, WS22H, &
        WD11L, WD21L, WD12L, WD22L, WD11H, WD21H, WD12H, WD22H, &
        UX11L, UX21L, UX12L, UX22L, UX11H, UX21H, UX12H, UX22H, &
        UY11L, UY21L, UY12L, UY22L, UY11H, UY21H, UY12H, UY22H
REAL :: UXL, UXH, UYL, UYH, UXNOW, UYNOW, WSNOW, WDNOW

INTEGER :: I, I1, I2, J1, J2

!C => L%HEAD

DO I = 1, L%NUM_NODES
    
   CALL GET_BILINEAR_INTERPOLATE_COEFFS(L%IX(I), L%IY(I), X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

! Wind speed and wind direction (lo)
   WS12L = WSLO(I1, J2) ; WS22L = WSLO(I2, J2)
   WS11L = WSLO(I1, J1) ; WS21L = WSLO(I2, J1)
   
   WD12L = WDLO(I1, J2) ; WD22L = WDLO(I2, J2)
   WD11L = WDLO(I1, J1) ; WD21L = WDLO(I2, J1)

! Convert to x and y components
   UX12L = UX_FROM_WSWD(WS12L, WD12L) ; UX22L = UX_FROM_WSWD(WS22L, WD22L)
   UX11L = UX_FROM_WSWD(WS11L, WD11L) ; UX21L = UX_FROM_WSWD(WS21L, WD21L)

   UY12L = UY_FROM_WSWD(WS12L, WD12L) ; UY22L = UY_FROM_WSWD(WS22L, WD22L)
   UY11L = UY_FROM_WSWD(WS11L, WD11L) ; UY21L = UY_FROM_WSWD(WS21L, WD21L)
   
! Interpolate spatially
   UXL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11L, UX21L, UX12L, UX22L)
   UYL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11L, UY21L, UY12L, UY22L)

! Wind speed and wind direction (hi)
   WS12H = WSHI(I1, J2) ; WS22H = WSHI(I2, J2)
   WS11H = WSHI(I1, J1) ; WS21H = WSHI(I2, J1)
   
   WD12H = WDHI(I1, J2) ; WD22H = WDHI(I2, J2)
   WD11H = WDHI(I1, J1) ; WD21H = WDHI(I2, J1)

! Convert to x and y components
   UX12H = UX_FROM_WSWD(WS12H, WD12H) ; UX22H = UX_FROM_WSWD(WS22H, WD22H)
   UX11H = UX_FROM_WSWD(WS11H, WD11H) ; UX21H = UX_FROM_WSWD(WS21H, WD21H)

   UY12H = UY_FROM_WSWD(WS12H, WD12H) ; UY22H = UY_FROM_WSWD(WS22H, WD22H)
   UY11H = UY_FROM_WSWD(WS11H, WD11H) ; UY21H = UY_FROM_WSWD(WS21H, WD21H)
   
! Interpolate spatially
   UXH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11H, UX21H, UX12H, UX22H)
   UYH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11H, UY21H, UY12H, UY22H)

! Interpolate temporally
   UXNOW = UXL + F * (UXH - UXL)
   UYNOW = UYL + F * (UYH - UYL)
   
! Convert to wind speed and direction
   IF      (UXNOW .EQ. 0. .AND. UYNOW .EQ. 0.) THEN 
      WDNOW = 0.
   ELSE IF (UXNOW .GT. 0. .AND. UYNOW .EQ. 0.) THEN
      WDNOW = 0.5*PI
   ELSE IF (UXNOW .LT. 0. .AND. UYNOW .EQ. 0.) THEN          
      WDNOW = 1.5*PI          
   ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .GT. 0.) THEN
      WDNOW = 0.0*PI
   ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .LT. 0.) THEN          
      WDNOW = 1.0*PI
   ELSE
      IF (UXNOW .GT. 0. .AND. UYNOW .GT. 0.) WDNOW = 0.     + ATAN(  UXNOW /  UYNOW ) 
      IF (UXNOW .GT. 0. .AND. UYNOW .LT. 0.) WDNOW = 0.5*PI + ATAN( -UYNOW /  UXNOW )
      IF (UXNOW .LT. 0. .AND. UYNOW .LT. 0.) WDNOW = PI     + ATAN(  UXNOW /  UYNOW )
      IF (UXNOW .LT. 0. .AND. UYNOW .GT. 0.) WDNOW = 1.5*PI + ATAN(  UYNOW / ABS(UXNOW) )
   ENDIF

   WSNOW = SQRT(UXNOW*UXNOW + UYNOW*UYNOW)
   
   WDNOW = WDNOW * 180. / PI
   WDNOW = WDNOW + 180. 
   IF (WDNOW .GT. 360) WDNOW = WDNOW - 360.

   L%WD20_INTERP(I) = WDNOW + PERTURB_WD
   IF (L%WD20_INTERP(I) .GT. 360.) L%WD20_INTERP(I) = L%WD20_INTERP(I) - 360.
   IF (L%WD20_INTERP(I) .LT.   0.) L%WD20_INTERP(I) = L%WD20_INTERP(I) + 360.
   L%WD20_NOW(I) = L%WD20_INTERP(I)

   L%WS20_INTERP(I) = MAX(WSNOW + PERTURB_WS, 0.0)
   L%WS20_NOW(I) = L%WS20_INTERP(I)
   L%WSMF(I) = L%WS20_NOW(I) * MAX((WAF%R4(L%IX(I),L%IY(I),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
   
   !C => C%NEXT

ENDDO

! *****************************************************************************
END SUBROUTINE INTERP_WIND_LINKEDLIST_BILINEAR_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WIND_SINGLE_BILINEAR(NODEIN,WSLO,WSHI,WDLO,WDHI,F)
! *****************************************************************************

TYPE(NODE), POINTER, INTENT(OUT) :: NODEIN
REAL, DIMENSION(:,:), INTENT(IN) :: WSLO,WSHI,WDLO,WDHI
REAL, INTENT(IN) :: F
TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY
REAL :: WS11L, WS21L, WS12L, WS22L, WS11H, WS21H, WS12H, WS22H, &
        WD11L, WD21L, WD12L, WD22L, WD11H, WD21H, WD12H, WD22H, &
        UX11L, UX21L, UX12L, UX22L, UX11H, UX21H, UX12H, UX22H, &
        UY11L, UY21L, UY12L, UY22L, UY11H, UY21H, UY12H, UY22H
REAL :: UXL, UXH, UYL, UYH, UXNOW, UYNOW, WSNOW, WDNOW

INTEGER :: I1, I2, J1, J2

C => NODEIN
    
CALL GET_BILINEAR_INTERPOLATE_COEFFS(C%IX, C%IY, X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

! Wind speed and wind direction (lo)
WS12L = WSLO(I1, J2) ; WS22L = WSLO(I2, J2)
WS11L = WSLO(I1, J1) ; WS21L = WSLO(I2, J1)
   
WD12L = WDLO(I1, J2) ; WD22L = WDLO(I2, J2)
WD11L = WDLO(I1, J1) ; WD21L = WDLO(I2, J1)

! Convert to x and y components
UX12L = UX_FROM_WSWD(WS12L, WD12L) ; UX22L = UX_FROM_WSWD(WS22L, WD22L)
UX11L = UX_FROM_WSWD(WS11L, WD11L) ; UX21L = UX_FROM_WSWD(WS21L, WD21L)

UY12L = UY_FROM_WSWD(WS12L, WD12L) ; UY22L = UY_FROM_WSWD(WS22L, WD22L)
UY11L = UY_FROM_WSWD(WS11L, WD11L) ; UY21L = UY_FROM_WSWD(WS21L, WD21L)
   
! Interpolate spatially
UXL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11L, UX21L, UX12L, UX22L)
UYL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11L, UY21L, UY12L, UY22L)

! Wind speed and wind direction (hi)
WS12H = WSHI(I1, J2) ; WS22H = WSHI(I2, J2)
WS11H = WSHI(I1, J1) ; WS21H = WSHI(I2, J1)
WD12H = WDHI(I1, J2) ; WD22H = WDHI(I2, J2)
WD11H = WDHI(I1, J1) ; WD21H = WDHI(I2, J1)

! Convert to x and y components
UX12H = UX_FROM_WSWD(WS12H, WD12H) ; UX22H = UX_FROM_WSWD(WS22H, WD22H)
UX11H = UX_FROM_WSWD(WS11H, WD11H) ; UX21H = UX_FROM_WSWD(WS21H, WD21H)

UY12H = UY_FROM_WSWD(WS12H, WD12H) ; UY22H = UY_FROM_WSWD(WS22H, WD22H)
UY11H = UY_FROM_WSWD(WS11H, WD11H) ; UY21H = UY_FROM_WSWD(WS21H, WD21H)
   
! Interpolate spatially
UXH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11H, UX21H, UX12H, UX22H)
UYH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11H, UY21H, UY12H, UY22H)

! Interpolate temporally
UXNOW = UXL + F * (UXH - UXL)
UYNOW = UYL + F * (UYH - UYL)
   
! Convert to wind speed and direction
IF      (UXNOW .EQ. 0. .AND. UYNOW .EQ. 0.) THEN 
   WDNOW = 0.
ELSE IF (UXNOW .GT. 0. .AND. UYNOW .EQ. 0.) THEN
   WDNOW = 0.5*PI
ELSE IF (UXNOW .LT. 0. .AND. UYNOW .EQ. 0.) THEN          
   WDNOW = 1.5*PI          
ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .GT. 0.) THEN
   WDNOW = 0.0*PI
ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .LT. 0.) THEN          
   WDNOW = 1.0*PI
ELSE
   IF (UXNOW .GT. 0. .AND. UYNOW .GT. 0.) WDNOW = 0.     + ATAN(  UXNOW /  UYNOW ) 
   IF (UXNOW .GT. 0. .AND. UYNOW .LT. 0.) WDNOW = 0.5*PI + ATAN( -UYNOW /  UXNOW )
   IF (UXNOW .LT. 0. .AND. UYNOW .LT. 0.) WDNOW = PI     + ATAN(  UXNOW /  UYNOW )
   IF (UXNOW .LT. 0. .AND. UYNOW .GT. 0.) WDNOW = 1.5*PI + ATAN(  UYNOW / ABS(UXNOW) )
ENDIF

WSNOW = SQRT(UXNOW*UXNOW + UYNOW*UYNOW)
   
WDNOW = WDNOW * 180. / PI
WDNOW = WDNOW + 180. 
IF (WDNOW .GT. 360) WDNOW = WDNOW - 360.

C%WD20_INTERP = WDNOW + PERTURB_WD
IF (C%WD20_INTERP .GT. 360.) C%WD20_INTERP = C%WD20_INTERP - 360.
IF (C%WD20_INTERP .LT.   0.) C%WD20_INTERP = C%WD20_INTERP + 360.
C%WD20_NOW = C%WD20_INTERP

C%WS20_INTERP = MAX(WSNOW + PERTURB_WS, 0.0)
C%WS20_NOW = C%WS20_INTERP
C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
   
! *****************************************************************************
END SUBROUTINE INTERP_WIND_SINGLE_BILINEAR
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_WIND_SINGLE_BILINEAR_NL(NL,NODE_INDEX,WSLO,WSHI,WDLO,WDHI,F) ! List of nodes version of INTERP_WIND_SINGLE_BILINEAR
! *****************************************************************************

TYPE(NODE_LIST), INTENT(INOUT) :: NL
INTEGER, INTENT(IN) :: NODE_INDEX
REAL, DIMENSION(:,:), INTENT(IN) :: WSLO,WSHI,WDLO,WDHI
REAL, INTENT(IN) :: F
!TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY
REAL :: WS11L, WS21L, WS12L, WS22L, WS11H, WS21H, WS12H, WS22H, &
        WD11L, WD21L, WD12L, WD22L, WD11H, WD21H, WD12H, WD22H, &
        UX11L, UX21L, UX12L, UX22L, UX11H, UX21H, UX12H, UX22H, &
        UY11L, UY21L, UY12L, UY22L, UY11H, UY21H, UY12H, UY22H
REAL :: UXL, UXH, UYL, UYH, UXNOW, UYNOW, WSNOW, WDNOW

INTEGER :: I1, I2, J1, J2

!C => NODEIN
    
CALL GET_BILINEAR_INTERPOLATE_COEFFS(NL%IX(NODE_INDEX), NL%IY(NODE_INDEX), X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

! Wind speed and wind direction (lo)
WS12L = WSLO(I1, J2) ; WS22L = WSLO(I2, J2)
WS11L = WSLO(I1, J1) ; WS21L = WSLO(I2, J1)
   
WD12L = WDLO(I1, J2) ; WD22L = WDLO(I2, J2)
WD11L = WDLO(I1, J1) ; WD21L = WDLO(I2, J1)

! Convert to x and y components
UX12L = UX_FROM_WSWD(WS12L, WD12L) ; UX22L = UX_FROM_WSWD(WS22L, WD22L)
UX11L = UX_FROM_WSWD(WS11L, WD11L) ; UX21L = UX_FROM_WSWD(WS21L, WD21L)

UY12L = UY_FROM_WSWD(WS12L, WD12L) ; UY22L = UY_FROM_WSWD(WS22L, WD22L)
UY11L = UY_FROM_WSWD(WS11L, WD11L) ; UY21L = UY_FROM_WSWD(WS21L, WD21L)
   
! Interpolate spatially
UXL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11L, UX21L, UX12L, UX22L)
UYL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11L, UY21L, UY12L, UY22L)

! Wind speed and wind direction (hi)
WS12H = WSHI(I1, J2) ; WS22H = WSHI(I2, J2)
WS11H = WSHI(I1, J1) ; WS21H = WSHI(I2, J1)
WD12H = WDHI(I1, J2) ; WD22H = WDHI(I2, J2)
WD11H = WDHI(I1, J1) ; WD21H = WDHI(I2, J1)

! Convert to x and y components
UX12H = UX_FROM_WSWD(WS12H, WD12H) ; UX22H = UX_FROM_WSWD(WS22H, WD22H)
UX11H = UX_FROM_WSWD(WS11H, WD11H) ; UX21H = UX_FROM_WSWD(WS21H, WD21H)

UY12H = UY_FROM_WSWD(WS12H, WD12H) ; UY22H = UY_FROM_WSWD(WS22H, WD22H)
UY11H = UY_FROM_WSWD(WS11H, WD11H) ; UY21H = UY_FROM_WSWD(WS21H, WD21H)
   
! Interpolate spatially
UXH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UX11H, UX21H, UX12H, UX22H)
UYH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, UY11H, UY21H, UY12H, UY22H)

! Interpolate temporally
UXNOW = UXL + F * (UXH - UXL)
UYNOW = UYL + F * (UYH - UYL)
   
! Convert to wind speed and direction
IF      (UXNOW .EQ. 0. .AND. UYNOW .EQ. 0.) THEN 
   WDNOW = 0.
ELSE IF (UXNOW .GT. 0. .AND. UYNOW .EQ. 0.) THEN
   WDNOW = 0.5*PI
ELSE IF (UXNOW .LT. 0. .AND. UYNOW .EQ. 0.) THEN          
   WDNOW = 1.5*PI          
ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .GT. 0.) THEN
   WDNOW = 0.0*PI
ELSE IF (UXNOW .EQ. 0. .AND. UYNOW .LT. 0.) THEN          
   WDNOW = 1.0*PI
ELSE
   IF (UXNOW .GT. 0. .AND. UYNOW .GT. 0.) WDNOW = 0.     + ATAN(  UXNOW /  UYNOW ) 
   IF (UXNOW .GT. 0. .AND. UYNOW .LT. 0.) WDNOW = 0.5*PI + ATAN( -UYNOW /  UXNOW )
   IF (UXNOW .LT. 0. .AND. UYNOW .LT. 0.) WDNOW = PI     + ATAN(  UXNOW /  UYNOW )
   IF (UXNOW .LT. 0. .AND. UYNOW .GT. 0.) WDNOW = 1.5*PI + ATAN(  UYNOW / ABS(UXNOW) )
ENDIF

WSNOW = SQRT(UXNOW*UXNOW + UYNOW*UYNOW)
   
WDNOW = WDNOW * 180. / PI
WDNOW = WDNOW + 180. 
IF (WDNOW .GT. 360) WDNOW = WDNOW - 360.

NL%WD20_INTERP(NODE_INDEX) = WDNOW + PERTURB_WD
IF (NL%WD20_INTERP(NODE_INDEX) .GT. 360.) NL%WD20_INTERP(NODE_INDEX) = NL%WD20_INTERP(NODE_INDEX) - 360.
IF (NL%WD20_INTERP(NODE_INDEX) .LT.   0.) NL%WD20_INTERP(NODE_INDEX) = NL%WD20_INTERP(NODE_INDEX) + 360.
NL%WD20_NOW(NODE_INDEX) = NL%WD20_INTERP(NODE_INDEX)

NL%WS20_INTERP(NODE_INDEX) = MAX(WSNOW + PERTURB_WS, 0.0)
NL%WS20_NOW(NODE_INDEX) = NL%WS20_INTERP(NODE_INDEX)
NL%WSMF(NODE_INDEX) = NL%WS20_NOW(NODE_INDEX) * MAX((WAF%R4(NL%IX(NODE_INDEX),NL%IY(NODE_INDEX),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
   
! *****************************************************************************
END SUBROUTINE INTERP_WIND_SINGLE_BILINEAR_NL
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION UX_FROM_WSWD(WS,WD)
! *****************************************************************************
   REAL, INTENT(IN) :: WS, WD
   UX_FROM_WSWD = WS * COS( (WD + 90.) * PI / 180.) 
! *****************************************************************************
END FUNCTION UX_FROM_WSWD
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION UY_FROM_WSWD(WS,WD)
! *****************************************************************************
   REAL, INTENT(IN) :: WS, WD
   UY_FROM_WSWD = WS * SIN( (WD - 90.) * PI / 180.) 
! *****************************************************************************
END FUNCTION UY_FROM_WSWD
! *****************************************************************************

! *****************************************************************************
SUBROUTINE GET_BILINEAR_INTERPOLATE_COEFFS(IX, IY, X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)
! *****************************************************************************

INTEGER, INTENT(IN) :: IX, IY
REAL, INTENT(OUT) :: X1, Y1, X2, Y2, CX, CY
INTEGER, INTENT(OUT) :: I1, J1, I2, J2

REAL :: XLL_WX, YLL_WX, CELLSIZE_WX, XLL_FUEL, YLL_FUEL, CELLSIZE_FUEL
INTEGER :: NCOL_WX, NROW_WX

XLL_WX        = WS%XLLCORNER
YLL_WX        = WS%YLLCORNER
CELLSIZE_WX   = WS%CELLSIZE
NCOL_WX       = WS%NCOLS
NROW_WX       = WS%NROWS

XLL_FUEL      = ADJ%XLLCORNER
YLL_FUEL      = ADJ%YLLCORNER
CELLSIZE_FUEL = ADJ%CELLSIZE

CX = XLL_FUEL + (REAL(IX) - 0.5) * CELLSIZE_FUEL
CY = YLL_FUEL + (REAL(IY) - 0.5) * CELLSIZE_FUEL

I1 = 1 + NINT( (CX - XLL_WX) / CELLSIZE_WX )
I1 = MAX ( MIN(I1    , NCOL_WX), 1 )
I2 = MAX ( MIN(I1 + 1, NCOL_WX), 1 )

J1 = 1 + NINT( (CY - YLL_WX) / CELLSIZE_WX )
J1 = MAX ( MIN(J1,     NROW_WX), 1 )
J2 = MAX ( MIN(J2 + 1, NROW_WX), 1 )

X1 = XLL_WX + (REAL(I1) - 0.5) * CELLSIZE_WX
X2 = XLL_WX + (REAL(I2) - 0.5) * CELLSIZE_WX
Y1 = YLL_WX + (REAL(J1) - 0.5) * CELLSIZE_WX
Y2 = YLL_WX + (REAL(J2) - 0.5) * CELLSIZE_WX

! *****************************************************************************
END SUBROUTINE GET_BILINEAR_INTERPOLATE_COEFFS
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION BILINEAR_INTERPOLATE(X, Y, X1, Y1, X2, Y2, Q11, Q21, Q12, Q22)
! *****************************************************************************

REAL, INTENT(IN) :: X, Y, X1, Y1, X2, Y2, Q11, Q21, Q12, Q22
REAL :: X2MX1, Y2MY1, DENOM, X2MX, Y2MY, XMX1, YMY1, NUMER1, NUMER2, NUMER3, &
        NUMER4, P

X2MX1 = X2 - X1
Y2MY1 = Y2 - Y1
DENOM = X2MX1 * Y2MY1 

X2MX  = X2 - X
Y2MY  = Y2 - Y
XMX1  = X - X1
YMY1  = Y - Y1

IF (DENOM .GT. 1E-3) THEN
   NUMER1 = X2MX * Y2MY * Q11
   NUMER2 = XMX1 * Y2MY * Q21
   NUMER3 = X2MX * YMY1 * Q12
   NUMER4 = XMX1 * YMY1 * Q22
   P = ( NUMER1 + NUMER2 + NUMER3 + NUMER4 ) / DENOM
ELSE IF (X2MX1 .LT. 1E-3) THEN ! Only interpolate in y direction
   P = ( Q11 * Y2MY + Q12 * YMY1 ) / Y2MY1
ELSE ! Only interpolate in x direction
   P = ( Q11 * X2MX + Q21 * XMX1 ) / X2MX1
ENDIF

BILINEAR_INTERPOLATE = P 

! *****************************************************************************
END FUNCTION BILINEAR_INTERPOLATE
! *****************************************************************************

! *****************************************************************************
INTEGER FUNCTION WX_ICOL_FROM_ANALYSIS_IX(IX_IN)
! *****************************************************************************

INTEGER, INTENT(IN) :: IX_IN
INTEGER :: IX

IX                       = MAX ( MIN (IX_IN,                 FBFM%NCOLS ), 1 )
WX_ICOL_FROM_ANALYSIS_IX = MAX ( MIN (ICOL_ANALYSIS_F2C(IX),   WS%NCOLS ), 1 )

! *****************************************************************************
END FUNCTION WX_ICOL_FROM_ANALYSIS_IX
! *****************************************************************************

! *****************************************************************************
INTEGER FUNCTION WX_IROW_FROM_ANALYSIS_IY(IY_IN)
! *****************************************************************************

INTEGER, INTENT(IN) :: IY_IN
INTEGER :: IY

IY                       = MAX ( MIN (IY_IN,                 FBFM%NROWS ), 1 )
WX_IROW_FROM_ANALYSIS_IY = MAX ( MIN (IROW_ANALYSIS_F2C(IY),   WS%NROWS ), 1 )

! *****************************************************************************
END FUNCTION WX_IROW_FROM_ANALYSIS_IY
! *****************************************************************************

! *****************************************************************************
INTEGER FUNCTION ICOL_FINE_TO_COARSE(IX_IN)
! *****************************************************************************

INTEGER, INTENT(IN) :: IX_IN
INTEGER :: IX

IX = MAX(MIN(IX_IN, FBFM%NCOLS),1)
ICOL_FINE_TO_COARSE = MAX(MIN(ICOL_ANALYSIS_F2C(IX),WS%NCOLS),1)

! *****************************************************************************
END FUNCTION ICOL_FINE_TO_COARSE
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE_NL(NL,NODE_INDEX,LO,HI,F,IQUANTITY) ! List of nodes version of INTERP_RASTER_LINKEDLIST_SINGLE
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: NL
INTEGER, INTENT(IN) :: NODE_INDEX
REAL, DIMENSION(:,:), INTENT(IN) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
INTEGER :: ICOL,IROW
!TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.

!C => NODEIN
ICOL = ICOL_ANALYSIS_F2C(NL%IX(NODE_INDEX))
IROW = IROW_ANALYSIS_F2C(NL%IY(NODE_INDEX))

SELECT CASE (IQUANTITY)

   CASE (1)
      NL%M1(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%M1(NODE_INDEX) = MAX(NL%M1(NODE_INDEX) + PERTURB_M1, 0.01)

   CASE (2)
      NL%M10(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%M10(NODE_INDEX) = MAX(NL%M10(NODE_INDEX) + PERTURB_M10, 0.01)

   CASE (3)
      NL%M100(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%M100(NODE_INDEX) = MAX(NL%M100(NODE_INDEX) + PERTURB_M100, 0.01)

   CASE (4)
      NL%MLH(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%MLH(NODE_INDEX) = MAX(NL%MLH(NODE_INDEX) + PERTURB_MLH, 0.3)

   CASE (5)
      NL%MLW(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%MLW(NODE_INDEX) = MAX(NL%MLW(NODE_INDEX) + PERTURB_MLW, 0.6)

   CASE (6)
      NL%FMC(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%FMC(NODE_INDEX) = NL%FMC(NODE_INDEX) + PERTURB_FMC

   CASE (7)
      NL%WS20_INTERP(NODE_INDEX) = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      NL%WS20_INTERP(NODE_INDEX) = MAX(NL%WS20_INTERP(NODE_INDEX) + PERTURB_WS, 0.0)
      NL%WS20_NOW(NODE_INDEX) = NL%WS20_INTERP(NODE_INDEX)
      NL%WSMF(NODE_INDEX) = NL%WS20_NOW(NODE_INDEX) * MAX((WAF%R4(NL%IX(NODE_INDEX),NL%IY(NODE_INDEX),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR

END SELECT

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE(NODEIN,LO,HI,F,IQUANTITY)
! *****************************************************************************

TYPE (NODE), POINTER, INTENT(OUT) :: NODEIN
REAL, DIMENSION(:,:), INTENT(IN) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
INTEGER :: ICOL,IROW
TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.

C => NODEIN
ICOL = ICOL_ANALYSIS_F2C(C%IX)
IROW = IROW_ANALYSIS_F2C(C%IY)

SELECT CASE (IQUANTITY)

   CASE (1)
      C%M1 = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%M1 = MAX(C%M1 + PERTURB_M1, 0.01)

   CASE (2)
      C%M10 = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%M10 = MAX(C%M10 + PERTURB_M10, 0.01)

   CASE (3)
      C%M100 = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%M100 = MAX(C%M100 + PERTURB_M100, 0.01)

   CASE (4)
      C%MLH = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%MLH = MAX(C%MLH + PERTURB_MLH, 0.3)

   CASE (5)
      C%MLW = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%MLW = MAX(C%MLW + PERTURB_MLW, 0.6)

   CASE (6)
      C%FMC = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%FMC = C%FMC + PERTURB_FMC

   CASE (7)
      C%WS20_INTERP = LO(ICOL,IROW) + F * (HI(ICOL,IROW) - LO(ICOL,IROW) )
      C%WS20_INTERP = MAX(C%WS20_INTERP + PERTURB_WS, 0.0)
      C%WS20_NOW = C%WS20_INTERP
      C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR

END SELECT

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE_BILINEAR(NODEIN,LO,HI,F,IQUANTITY)
! *****************************************************************************

TYPE (NODE), POINTER, INTENT(OUT) :: NODEIN
REAL, DIMENSION(:,:), INTENT(IN) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY, PL, PH, PNOW
REAL :: Q11L, Q21L, Q12L, Q22L, Q11H, Q21H, Q12H, Q22H
INTEGER :: I1, I2, J1, J2

C => NODEIN

CALL GET_BILINEAR_INTERPOLATE_COEFFS(C%IX, C%IY, X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

Q12L = LO(I1, J2) ; Q22L = LO(I2, J2)
Q11L = LO(I1, J1) ; Q21L = LO(I2, J1)
PL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11L, Q21L, Q12L, Q22L)
         
Q12H = HI(I1, J2) ; Q22H = HI(I2, J2)
Q11H = HI(I1, J1) ; Q21H = HI(I2, J1)
PH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11H, Q21H, Q12H, Q22H)
   
PNOW = PL + F * (PH - PL)

SELECT CASE (IQUANTITY)
   CASE (1)
      C%M1   = MAX(PNOW + PERTURB_M1  , 0.01)
   CASE (2)
      C%M10  = MAX(PNOW + PERTURB_M10 , 0.01)
   CASE (3)
      C%M100 = MAX(PNOW + PERTURB_M100, 0.01)
   CASE (4)
      C%MLH  = MAX(PNOW + PERTURB_MLH , 0.30)
   CASE (5)
      C%MLW  = MAX(PNOW + PERTURB_MLW , 0.60)
   CASE (6)
      C%FMC  = PNOW + PERTURB_FMC
   CASE (7)
      C%WS20_INTERP = MAX(PNOW + PERTURB_WS, 0.0)
      C%WS20_NOW = C%WS20_INTERP
      C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
END SELECT

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE_BILINEAR
! *****************************************************************************

! *****************************************************************************
SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE_BILINEAR_NL( NL, NODE_INDEX, LO, HI, F, IQUANTITY) ! List of nodes version
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: NL
INTEGER, INTENT(IN) :: NODE_INDEX
REAL, DIMENSION(:,:), INTENT(IN) :: LO,HI
INTEGER, INTENT(IN) :: IQUANTITY
REAL, INTENT(IN) :: F
!TYPE(NODE), POINTER :: C
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.
REAL :: X1, X2, Y1, Y2, CX, CY, PL, PH, PNOW
REAL :: Q11L, Q21L, Q12L, Q22L, Q11H, Q21H, Q12H, Q22H
INTEGER :: I1, I2, J1, J2

!C => NODEIN

CALL GET_BILINEAR_INTERPOLATE_COEFFS(NL%IX(NODE_INDEX), NL%IY(NODE_INDEX), X1, Y1, X2, Y2, I1, J1, I2, J2, CX, CY)

Q12L = LO(I1, J2) ; Q22L = LO(I2, J2)
Q11L = LO(I1, J1) ; Q21L = LO(I2, J1)
PL   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11L, Q21L, Q12L, Q22L)
         
Q12H = HI(I1, J2) ; Q22H = HI(I2, J2)
Q11H = HI(I1, J1) ; Q21H = HI(I2, J1)
PH   = BILINEAR_INTERPOLATE(CX, CY, X1, Y1, X2, Y2, Q11H, Q21H, Q12H, Q22H)
   
PNOW = PL + F * (PH - PL)

SELECT CASE (IQUANTITY)
   CASE (1)
      NL%M1(NODE_INDEX)   = MAX(PNOW + PERTURB_M1  , 0.01)
   CASE (2)
      NL%M10(NODE_INDEX)  = MAX(PNOW + PERTURB_M10 , 0.01)
   CASE (3)
      NL%M100(NODE_INDEX) = MAX(PNOW + PERTURB_M100, 0.01)
   CASE (4)
      NL%MLH(NODE_INDEX)  = MAX(PNOW + PERTURB_MLH , 0.30)
   CASE (5)
      NL%MLW(NODE_INDEX)  = MAX(PNOW + PERTURB_MLW , 0.60)
   CASE (6)
      NL%FMC(NODE_INDEX)  = PNOW + PERTURB_FMC
   CASE (7)
      NL%WS20_INTERP(NODE_INDEX) = MAX(PNOW + PERTURB_WS, 0.0)
      NL%WS20_NOW(NODE_INDEX) = NL%WS20_INTERP(NODE_INDEX)
      NL%WSMF(NODE_INDEX) = NL%WS20_NOW(NODE_INDEX) * MAX((WAF%R4(NL%IX(NODE_INDEX),NL%IY(NODE_INDEX),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
END SELECT

! *****************************************************************************
END SUBROUTINE INTERP_RASTER_LINKEDLIST_SINGLE_BILINEAR_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE APPLY_WIND_FLUCTUATIONS_NL(NL) ! List of nodes version to apply wind fluctuations
! *****************************************************************************

TYPE (NODE_LIST), INTENT(INOUT) :: NL
!TYPE(NODE), POINTER :: C
INTEGER :: I
REAL :: FAC1, FAC2, R2(1:2)
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.

CALL RANDOM_NUMBER(R2)
R2(1) = WIND_SPEED_FLUCTUATION_INTENSITY     * (R2(1) - 0.5)
R2(2) = WIND_DIRECTION_FLUCTUATION_INTENSITY * (R2(2) - 0.5)

FAC1 = 1. + R2(1)
FAC2 = R2(2) * 360.

!C => NL%HEAD
DO I = 1, NL%NUM_NODES
   NL%WS20_NOW(I) = FAC1 * NL%WS20_INTERP(I)
   NL%WSMF(I) = NL%WS20_NOW(I) * MAX((WAF%R4(NL%IX(I),NL%IY(I),1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
   NL%WD20_NOW(I) = NL%WD20_INTERP(I) + FAC2
   IF (NL%WD20_NOW(I) .GT. 360.) NL%WD20_NOW(I) = NL%WD20_NOW(I) - 360.
   IF (NL%WD20_NOW(I) .LT.   0.) NL%WD20_NOW(I) = NL%WD20_NOW(I) + 360.
   !C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE APPLY_WIND_FLUCTUATIONS_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE APPLY_WIND_FLUCTUATIONS(L)
! *****************************************************************************

TYPE (DLL), INTENT(INOUT) :: L
TYPE(NODE), POINTER :: C
INTEGER :: I
REAL :: FAC1, FAC2, R2(1:2)
REAL, PARAMETER :: CONVERSION_FACTOR = 5280./60.

CALL RANDOM_NUMBER(R2)
R2(1) = WIND_SPEED_FLUCTUATION_INTENSITY     * (R2(1) - 0.5)
R2(2) = WIND_DIRECTION_FLUCTUATION_INTENSITY * (R2(2) - 0.5)

FAC1 = 1. + R2(1)
FAC2 = R2(2) * 360.

C => L%HEAD
DO I = 1, L%NUM_NODES
   C%WS20_NOW = FAC1 * C%WS20_INTERP
   C%WSMF = C%WS20_NOW * MAX((WAF%R4(C%IX,C%IY,1) + PERTURB_WAF),0.) * CONVERSION_FACTOR
   C%WD20_NOW = C%WD20_INTERP + FAC2
   IF (C%WD20_NOW .GT. 360.) C%WD20_NOW = C%WD20_NOW - 360.
   IF (C%WD20_NOW .LT.   0.) C%WD20_NOW = C%WD20_NOW + 360.
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE APPLY_WIND_FLUCTUATIONS
! *****************************************************************************

! *****************************************************************************
ELEMENTAL TYPE(DLL) FUNCTION NEW_DLL()
! *****************************************************************************

NEW_DLL = DLL(NULL(),NULL(),0)

! *****************************************************************************
END FUNCTION NEW_DLL
! *****************************************************************************
 
! *****************************************************************************
SUBROUTINE APPEND(DL2, IX, IY, T)
! *****************************************************************************

TYPE(DLL), INTENT(INOUT) :: DL2
INTEGER, INTENT(IN)      :: IX, IY
REAL, INTENT(IN) :: T
 
TYPE(NODE), POINTER :: NP
TYPE(NODE_WRAPPER), ALLOCATABLE :: TEMP(:)  ! Temporary array for resizing DWI_SU
INTEGER :: N  ! Store the new count DWI_SU

! If the list is empty
IF (DL2%NUM_NODES == 0) THEN
   CALL INIT(DL2, IX, IY, T)
   ALLOCATE(DL2%NODE_POINTERS(1))      ! DWI_SU
   DL2%NODE_POINTERS(1)%PTR => DL2%HEAD   ! DWI_SU
   RETURN
END IF
 
! Add new element ot the end
DL2%NUM_NODES = DL2%NUM_NODES + 1
N = SIZE(DL2%NODE_POINTERS)+1  ! Store the new count DWI_SU + YIREN DEBUG


NP => DL2%TAIL
ALLOCATE(DL2%TAIL)
DL2%TAIL%IX         =  IX
DL2%TAIL%IY         =  IY
DL2%TAIL%TIME_ADDED =  T

DL2%TAIL%IFBFM   =  FBFM%I2(IX,IY,1)
#ifdef _WUI
IF (USE_BLDG_SPREAD_MODEL) DL2%TAIL%IBLDGFM =  BLDG_FUEL_MODEL%I2(IX,IY,1)
#endif
DL2%TAIL%ADJ     =  ADJ%R4(IX,IY,1)
DL2%TAIL%TANSLP2 =  TANSLP2(MAX(MIN(NINT(SLP%R4(IX,IY,1)),90),0))

DL2%TAIL%PREV       => NP
DL2%TAIL%PREV%NEXT  => DL2%TAIL

#ifdef _WUI
! Resize NODE_POINTERS array dynamically DWI_SU
ALLOCATE(TEMP(N-1))
TEMP = DL2%NODE_POINTERS
DEALLOCATE(DL2%NODE_POINTERS)
ALLOCATE(DL2%NODE_POINTERS(N))
DL2%NODE_POINTERS(1:N-1) = TEMP
DEALLOCATE(TEMP) 

! Store the new node in the array DWI_SU
NULLIFY(DL2%NODE_POINTERS(N)%PTR)
DL2%NODE_POINTERS(N)%PTR => DL2%TAIL
#endif
   
! *****************************************************************************   
END SUBROUTINE APPEND
! *****************************************************************************


! *****************************************************************************
SUBROUTINE APPEND_TO_DYNAMIC_ARRAY(IX, IY, N_ROWS, DYNAMIC_ARRAY)
! *****************************************************************************
   
INTEGER, INTENT(IN) :: IX, IY
INTEGER, INTENT(IN) :: N_ROWS
REAL, ALLOCATABLE, INTENT(INOUT), DIMENSION(:,:) :: DYNAMIC_ARRAY

! Remove the copy and paste part of the code that appends to the dynamic array, to improve performance.
! It uses more memory, because it creates an array with a fixed size, but is faster than the previous version.
DYNAMIC_ARRAY(N_ROWS, 1) = REAL(IX)
DYNAMIC_ARRAY(N_ROWS, 2) = REAL(IY)

! *****************************************************************************
END SUBROUTINE APPEND_TO_DYNAMIC_ARRAY
! *****************************************************************************



! *****************************************************************************
ELEMENTAL SUBROUTINE INIT(DL2, IX, IY, T)
! *****************************************************************************

TYPE(DLL), INTENT(INOUT) :: DL2
INTEGER, INTENT(IN)      :: IX, IY
REAL, INTENT(IN) :: T

ALLOCATE(DL2%HEAD)
DL2%TAIL => DL2%HEAD
DL2%TAIL%IX = IX
DL2%TAIL%IY = IY
DL2%TAIL%IFBFM      =  FBFM%I2(IX,IY,1)
DL2%TAIL%ADJ        =  ADJ%R4(IX,IY,1)
DL2%TAIL%TANSLP2    =  TANSLP2(MAX(MIN(NINT(SLP%R4(IX,IY,1)),90),0))
DL2%TAIL%TIME_ADDED =  T
DL2%NUM_NODES = 1

! *****************************************************************************
END SUBROUTINE INIT
! *****************************************************************************
 
! *****************************************************************************
SUBROUTINE INIT_NODE_LIST(NL, N) ! Allocates all of the lists in node list with n nodes to allocate
! *****************************************************************************
   TYPE(NODE_LIST), INTENT(INOUT) :: NL ! Node list to initialize
   INTEGER, INTENT(IN) :: N ! Number of nodes to allocate
   IF (ALLOCATED(NL%IX)) RETURN ! Already initialized; arrays persist across calls
   NL%NUM_NODES = 0
   ALLOCATE(NL%CROWN_FIRE(N));            NL%CROWN_FIRE = 0
   ALLOCATE(NL%IX(N));                    NL%IX = -1
   ALLOCATE(NL%IY(N));                    NL%IY = -1
   ALLOCATE(NL%BURNED(N));                NL%BURNED = .FALSE.
   ALLOCATE(NL%JUST_TAGGED(N));           NL%JUST_TAGGED = .TRUE.
   ALLOCATE(NL%CRITICAL_FLIN(N));         NL%CRITICAL_FLIN = 9E9
   ALLOCATE(NL%DPHIDX_LIMITED(N));        NL%DPHIDX_LIMITED = 0.
   ALLOCATE(NL%DPHIDY_LIMITED(N));        NL%DPHIDY_LIMITED = 0.
   ALLOCATE(NL%FLAME_LENGTH(N));          NL%FLAME_LENGTH = 0.
   ALLOCATE(NL%FLIN_CANOPY(N));           NL%FLIN_CANOPY = 0.
   ALLOCATE(NL%FLIN_DMS_SURFACE(N));      NL%FLIN_DMS_SURFACE = 0.
   ALLOCATE(NL%FLIN_SURFACE(N));          NL%FLIN_SURFACE = 0.
   ALLOCATE(NL%FMC(N));                   NL%FMC = 0.
   ALLOCATE(NL%HPUA_CANOPY(N));           NL%HPUA_CANOPY = 0.
   ALLOCATE(NL%HPUA_SURFACE(N));           NL%HPUA_SURFACE = 0.
   ALLOCATE(NL%IR(N));                    NL%IR = 0.
   ALLOCATE(NL%M1(N));                    NL%M1 = 0.
   ALLOCATE(NL%M10(N));                   NL%M10 = 0.
   ALLOCATE(NL%M100(N));                  NL%M100 = 0.
   ALLOCATE(NL%MLH(N));                   NL%MLH = 0.
   ALLOCATE(NL%MLW(N));                   NL%MLW = 0.
   ALLOCATE(NL%NORMVECTORX(N));           NL%NORMVECTORX = 0.
   ALLOCATE(NL%NORMVECTORY(N));           NL%NORMVECTORY = 0.
   ALLOCATE(NL%PHIS_SURFACE(N));          NL%PHIS_SURFACE = 0.
   ALLOCATE(NL%PHIW_CROWN(N));            NL%PHIW_CROWN = 0.
   ALLOCATE(NL%PHIW_SURFACE(N));          NL%PHIW_SURFACE = 0.
   ALLOCATE(NL%TIME_ADDED(N));            NL%TIME_ADDED = -1.0
   ALLOCATE(NL%TIME_OF_ARRIVAL(N));       NL%TIME_OF_ARRIVAL = -1.0
   ALLOCATE(NL%UX(N));                    NL%UX = 0.
   ALLOCATE(NL%UY(N));                    NL%UY = 0.
   ALLOCATE(NL%VELOCITY(N));              NL%VELOCITY = 0.
   ALLOCATE(NL%VELOCITY_DMS(N));          NL%VELOCITY_DMS = 0.
   ALLOCATE(NL%VS0(N));                   NL%VS0 = 0.
   ALLOCATE(NL%WD20_INTERP(N));            NL%WD20_INTERP = 0.
   ALLOCATE(NL%WD20_NOW(N));               NL%WD20_NOW = 0.
   ALLOCATE(NL%WS20_INTERP(N));            NL%WS20_INTERP = 0.
   ALLOCATE(NL%WS20_NOW(N));               NL%WS20_NOW = 0.
   ALLOCATE(NL%WSMF(N));                   NL%WSMF = 0.
   ALLOCATE(NL%VELOCITY_DMS_SURFACE(N));   NL%VELOCITY_DMS_SURFACE = 0.
   ALLOCATE(NL%NEED_SLOPE_CALC(N));       NL%NEED_SLOPE_CALC = .TRUE.
   ALLOCATE(NL%PHISX(N));                 NL%PHISX = -9999.
   ALLOCATE(NL%PHISY(N));                 NL%PHISY = -9999.
   ALLOCATE(NL%UXOUSX(N));                NL%UXOUSX = -9999.
   ALLOCATE(NL%UYOUSY(N));                NL%UYOUSY = -9999.
   ALLOCATE(NL%NORMVECTORX_DMS(N));       NL%NORMVECTORX_DMS = -9999.
   ALLOCATE(NL%NORMVECTORY_DMS(N));       NL%NORMVECTORY_DMS = -9999.
   ALLOCATE(NL%VBACK(N));                 NL%VBACK = -9999.
   ALLOCATE(NL%LOW(N));                   NL%LOW = -9999.
   ALLOCATE(NL%IFBFM(N));                 NL%IFBFM = 0
   ALLOCATE(NL%ADJ(N));                   NL%ADJ = 0.
   ALLOCATE(NL%TANSLP2(N));               NL%TANSLP2 = 0.
   ALLOCATE(NL%PHIP_OLD(N));              NL%PHIP_OLD = 0.
   ALLOCATE(NL%DUMPME(N));                NL%DUMPME = 0.
   ALLOCATE(NL%HRRPUA(N));                NL%HRRPUA = 0.
   ALLOCATE(NL%TIME_SUPPRESSED(N));        NL%TIME_SUPPRESSED = -1.0
#ifdef _SUPPRESSION
   ALLOCATE(NL%SUPPRESSION_ADJUSTMENT_FACTOR(N)); NL%SUPPRESSION_ADJUSTMENT_FACTOR = 1.0
   ALLOCATE(NL%SUPPRESSION_IDEG(N));              NL%SUPPRESSION_IDEG = 9999
   ALLOCATE(NL%SDI(N));                           NL%SDI = 0.
#endif
#ifdef _SMOKE
   ALLOCATE(NL%TIME_IGNITED(N));           NL%TIME_IGNITED = 0.
   ALLOCATE(NL%TIME_EXTINGUISHED(N));      NL%TIME_EXTINGUISHED = 0.
   ALLOCATE(NL%SMOKE_TFRAC(N));            NL%SMOKE_TFRAC = 0.
   ALLOCATE(NL%QDOT_AVG(N));               NL%QDOT_AVG = 0.
#endif
#ifdef _WUI
   ALLOCATE(NL%ELLIPSE_PARAMETERS(N))
   ALLOCATE(NL%BLDG_FUEL_MODEL(N));        NL%BLDG_FUEL_MODEL = 0
   ALLOCATE(NL%IBLDGFM(N));                NL%IBLDGFM = 1
   ALLOCATE(NL%SIGN_X(N));                 NL%SIGN_X = 1
   ALLOCATE(NL%SIGN_Y(N));                 NL%SIGN_Y = 1
   ALLOCATE(NL%BLDG_AREA(N));              NL%BLDG_AREA = 0.
   ALLOCATE(NL%BLDG_NONBURNABLE_FRAC(N));  NL%BLDG_NONBURNABLE_FRAC = 0.
   ALLOCATE(NL%BLDG_SEPARATION_DIST(N));   NL%BLDG_SEPARATION_DIST = 0.
   ALLOCATE(NL%BLDG_FOOTPRINT_FRAC(N));    NL%BLDG_FOOTPRINT_FRAC = 0.
   ALLOCATE(NL%RAD_DIST(N));               NL%RAD_DIST = 100.
   ALLOCATE(NL%WIND_PROP(N));              NL%WIND_PROP = 1.
   ALLOCATE(NL%HEAT_VALUE(N));             NL%HEAT_VALUE = 0.
   ALLOCATE(NL%HRR_TRANSIENT(N));          NL%HRR_TRANSIENT = 0.
   ALLOCATE(NL%ABSOLUTE_U(N));             NL%ABSOLUTE_U = 0.
   ALLOCATE(NL%TOTAL_DFC_RECEIVED(N));     NL%TOTAL_DFC_RECEIVED = 0.
   ALLOCATE(NL%TOTAL_RAD_RECEIVED(N));     NL%TOTAL_RAD_RECEIVED = 0.
#endif
#ifdef _UMDSPOTTING
   ALLOCATE(NL%TAU_EMBERGEN(N));           NL%TAU_EMBERGEN = 0.
   ALLOCATE(NL%LOCAL_EMBERGEN_DURATION(N)); NL%LOCAL_EMBERGEN_DURATION = 0.
   ALLOCATE(NL%T_START_SPOTTING(N));        NL%T_START_SPOTTING = -1.
   ALLOCATE(NL%T_END_SPOTTING(N));          NL%T_END_SPOTTING = -1.
#endif
! *****************************************************************************
END SUBROUTINE INIT_NODE_LIST
! *****************************************************************************

! *****************************************************************************
SUBROUTINE FREE_NODE_LIST(NL) ! Deallocates all lists
! *****************************************************************************
   TYPE(NODE_LIST), INTENT(INOUT) :: NL
   NL%NUM_NODES = 0
   IF (ALLOCATED(NL%CROWN_FIRE))             DEALLOCATE(NL%CROWN_FIRE)
   IF (ALLOCATED(NL%IX))                     DEALLOCATE(NL%IX)
   IF (ALLOCATED(NL%IY))                     DEALLOCATE(NL%IY)
   IF (ALLOCATED(NL%BURNED))                 DEALLOCATE(NL%BURNED)
   IF (ALLOCATED(NL%JUST_TAGGED))            DEALLOCATE(NL%JUST_TAGGED)
   IF (ALLOCATED(NL%CRITICAL_FLIN))          DEALLOCATE(NL%CRITICAL_FLIN)
   IF (ALLOCATED(NL%DPHIDX_LIMITED))         DEALLOCATE(NL%DPHIDX_LIMITED)
   IF (ALLOCATED(NL%DPHIDY_LIMITED))         DEALLOCATE(NL%DPHIDY_LIMITED)
   IF (ALLOCATED(NL%FLAME_LENGTH))           DEALLOCATE(NL%FLAME_LENGTH)
   IF (ALLOCATED(NL%FLIN_CANOPY))            DEALLOCATE(NL%FLIN_CANOPY)
   IF (ALLOCATED(NL%FLIN_DMS_SURFACE))       DEALLOCATE(NL%FLIN_DMS_SURFACE)
   IF (ALLOCATED(NL%FLIN_SURFACE))           DEALLOCATE(NL%FLIN_SURFACE)
   IF (ALLOCATED(NL%FMC))                    DEALLOCATE(NL%FMC)
   IF (ALLOCATED(NL%HPUA_CANOPY))            DEALLOCATE(NL%HPUA_CANOPY)
   IF (ALLOCATED(NL%HPUA_SURFACE))          DEALLOCATE(NL%HPUA_SURFACE)
   IF (ALLOCATED(NL%IR))                    DEALLOCATE(NL%IR)
   IF (ALLOCATED(NL%M1))                    DEALLOCATE(NL%M1)
   IF (ALLOCATED(NL%M10))                   DEALLOCATE(NL%M10)
   IF (ALLOCATED(NL%M100))                  DEALLOCATE(NL%M100)
   IF (ALLOCATED(NL%MLH))                   DEALLOCATE(NL%MLH)
   IF (ALLOCATED(NL%MLW))                   DEALLOCATE(NL%MLW)
   IF (ALLOCATED(NL%NORMVECTORX))           DEALLOCATE(NL%NORMVECTORX)
   IF (ALLOCATED(NL%NORMVECTORY))           DEALLOCATE(NL%NORMVECTORY)
   IF (ALLOCATED(NL%PHIS_SURFACE))          DEALLOCATE(NL%PHIS_SURFACE)
   IF (ALLOCATED(NL%PHIW_CROWN))            DEALLOCATE(NL%PHIW_CROWN)
   IF (ALLOCATED(NL%PHIW_SURFACE))          DEALLOCATE(NL%PHIW_SURFACE)
   IF (ALLOCATED(NL%TIME_ADDED))            DEALLOCATE(NL%TIME_ADDED)
   IF (ALLOCATED(NL%TIME_OF_ARRIVAL))       DEALLOCATE(NL%TIME_OF_ARRIVAL)
   IF (ALLOCATED(NL%UX))                    DEALLOCATE(NL%UX)
   IF (ALLOCATED(NL%UY))                    DEALLOCATE(NL%UY)
   IF (ALLOCATED(NL%VELOCITY))              DEALLOCATE(NL%VELOCITY)
   IF (ALLOCATED(NL%VELOCITY_DMS))          DEALLOCATE(NL%VELOCITY_DMS)
   IF (ALLOCATED(NL%VS0))                   DEALLOCATE(NL%VS0)
   IF (ALLOCATED(NL%WD20_INTERP))            DEALLOCATE(NL%WD20_INTERP)
   IF (ALLOCATED(NL%WD20_NOW))               DEALLOCATE(NL%WD20_NOW)
   IF (ALLOCATED(NL%WS20_INTERP))            DEALLOCATE(NL%WS20_INTERP)
   IF (ALLOCATED(NL%WS20_NOW))               DEALLOCATE(NL%WS20_NOW)
   IF (ALLOCATED(NL%WSMF))                   DEALLOCATE(NL%WSMF)
   IF (ALLOCATED(NL%VELOCITY_DMS_SURFACE))   DEALLOCATE(NL%VELOCITY_DMS_SURFACE)
   IF (ALLOCATED(NL%NEED_SLOPE_CALC))       DEALLOCATE(NL%NEED_SLOPE_CALC)
   IF (ALLOCATED(NL%PHISX))                 DEALLOCATE(NL%PHISX)
   IF (ALLOCATED(NL%PHISY))                 DEALLOCATE(NL%PHISY)
   IF (ALLOCATED(NL%UXOUSX))                DEALLOCATE(NL%UXOUSX)
   IF (ALLOCATED(NL%UYOUSY))                DEALLOCATE(NL%UYOUSY)
   IF (ALLOCATED(NL%NORMVECTORX_DMS))       DEALLOCATE(NL%NORMVECTORX_DMS)
   IF (ALLOCATED(NL%NORMVECTORY_DMS))       DEALLOCATE(NL%NORMVECTORY_DMS)
   IF (ALLOCATED(NL%VBACK))                 DEALLOCATE(NL%VBACK)
   IF (ALLOCATED(NL%LOW))                   DEALLOCATE(NL%LOW)
   IF (ALLOCATED(NL%IFBFM))                 DEALLOCATE(NL%IFBFM)
   IF (ALLOCATED(NL%ADJ))                   DEALLOCATE(NL%ADJ)
   IF (ALLOCATED(NL%TANSLP2))               DEALLOCATE(NL%TANSLP2)
   IF (ALLOCATED(NL%PHIP_OLD))              DEALLOCATE(NL%PHIP_OLD)
   IF (ALLOCATED(NL%DUMPME))                DEALLOCATE(NL%DUMPME)
   IF (ALLOCATED(NL%HRRPUA))                DEALLOCATE(NL%HRRPUA)
   IF (ALLOCATED(NL%TIME_SUPPRESSED))       DEALLOCATE(NL%TIME_SUPPRESSED)
#ifdef _SUPPRESSION
   IF (ALLOCATED(NL%SUPPRESSION_ADJUSTMENT_FACTOR)) DEALLOCATE(NL%SUPPRESSION_ADJUSTMENT_FACTOR)
   IF (ALLOCATED(NL%SUPPRESSION_IDEG))              DEALLOCATE(NL%SUPPRESSION_IDEG)
   IF (ALLOCATED(NL%SDI))                           DEALLOCATE(NL%SDI)
#endif
#ifdef _SMOKE
   IF (ALLOCATED(NL%TIME_IGNITED))           DEALLOCATE(NL%TIME_IGNITED)
   IF (ALLOCATED(NL%TIME_EXTINGUISHED))      DEALLOCATE(NL%TIME_EXTINGUISHED)
   IF (ALLOCATED(NL%SMOKE_TFRAC))            DEALLOCATE(NL%SMOKE_TFRAC)
   IF (ALLOCATED(NL%QDOT_AVG))               DEALLOCATE(NL%QDOT_AVG)
#endif
#ifdef _WUI
   IF (ALLOCATED(NL%ELLIPSE_PARAMETERS))     DEALLOCATE(NL%ELLIPSE_PARAMETERS)
   IF (ALLOCATED(NL%BLDG_FUEL_MODEL))        DEALLOCATE(NL%BLDG_FUEL_MODEL)
   IF (ALLOCATED(NL%IBLDGFM))                DEALLOCATE(NL%IBLDGFM)
   IF (ALLOCATED(NL%SIGN_X))                 DEALLOCATE(NL%SIGN_X)
   IF (ALLOCATED(NL%SIGN_Y))                 DEALLOCATE(NL%SIGN_Y)
   IF (ALLOCATED(NL%BLDG_AREA))              DEALLOCATE(NL%BLDG_AREA)
   IF (ALLOCATED(NL%BLDG_NONBURNABLE_FRAC))  DEALLOCATE(NL%BLDG_NONBURNABLE_FRAC)
   IF (ALLOCATED(NL%BLDG_SEPARATION_DIST))   DEALLOCATE(NL%BLDG_SEPARATION_DIST)
   IF (ALLOCATED(NL%BLDG_FOOTPRINT_FRAC))    DEALLOCATE(NL%BLDG_FOOTPRINT_FRAC)
   IF (ALLOCATED(NL%RAD_DIST))               DEALLOCATE(NL%RAD_DIST)
   IF (ALLOCATED(NL%WIND_PROP))              DEALLOCATE(NL%WIND_PROP)
   IF (ALLOCATED(NL%HEAT_VALUE))             DEALLOCATE(NL%HEAT_VALUE)
   IF (ALLOCATED(NL%HRR_TRANSIENT))          DEALLOCATE(NL%HRR_TRANSIENT)
   IF (ALLOCATED(NL%ABSOLUTE_U))             DEALLOCATE(NL%ABSOLUTE_U)
   IF (ALLOCATED(NL%TOTAL_DFC_RECEIVED))     DEALLOCATE(NL%TOTAL_DFC_RECEIVED)
   IF (ALLOCATED(NL%TOTAL_RAD_RECEIVED))     DEALLOCATE(NL%TOTAL_RAD_RECEIVED)
#endif
#ifdef _UMDSPOTTING
   IF (ALLOCATED(NL%TAU_EMBERGEN))           DEALLOCATE(NL%TAU_EMBERGEN)
   IF (ALLOCATED(NL%LOCAL_EMBERGEN_DURATION)) DEALLOCATE(NL%LOCAL_EMBERGEN_DURATION)
   IF (ALLOCATED(NL%T_START_SPOTTING))       DEALLOCATE(NL%T_START_SPOTTING)
   IF (ALLOCATED(NL%T_END_SPOTTING))         DEALLOCATE(NL%T_END_SPOTTING)
#endif
! *****************************************************************************
END SUBROUTINE FREE_NODE_LIST
! *****************************************************************************

! *****************************************************************************
SUBROUTINE COPY_NODE_TO_LIST(NL, IX, IY, T) ! Same function as APPEND but for the new node list
! *****************************************************************************
   TYPE(NODE_LIST), INTENT(INOUT) :: NL ! Node list
   INTEGER, INTENT(IN) :: IX, IY
   REAL, INTENT(IN) :: T
   INTEGER :: N

   NL%NUM_NODES = NL%NUM_NODES + 1
   N = NL%NUM_NODES

   NL%IX(N)         = IX
   NL%IY(N)         = IY
   NL%TIME_ADDED(N) = T
   NL%IFBFM(N)      = FBFM%I2(IX, IY, 1)
   NL%ADJ(N)        = ADJ%R4(IX, IY, 1)
   NL%TANSLP2(N)    = TANSLP2(MAX(MIN(NINT(SLP%R4(IX, IY, 1)), 90), 0))
   NL%WD20_NOW(N)   = WD%R4(IX, IY, 1)
   NL%WS20_NOW(N)   = WS%R4(IX, IY, 1)

#ifdef _WUI
   IF (USE_BLDG_SPREAD_MODEL) THEN
      NL%IBLDGFM(N)     = BLDG_FUEL_MODEL%I2(IX, IY, 1)
      NL%BLDG_AREA(N)   = BLDG_AREA%R4(IX, IY, 1)
      NL%BLDG_NONBURNABLE_FRAC(N) = BLDG_NONBURNABLE_FRAC%R4(IX, IY, 1)
      NL%BLDG_SEPARATION_DIST(N) = BLDG_SEPARATION_DIST%R4(IX, IY, 1)
      NL%BLDG_FOOTPRINT_FRAC(N)   = BLDG_FOOTPRINT_FRAC%R4(IX, IY, 1)
   ENDIF
#endif

#ifdef _UMDSPOTTING
   NL%TAU_EMBERGEN(N) = 0.
#endif
! *****************************************************************************
END SUBROUTINE COPY_NODE_TO_LIST
! *****************************************************************************

! *****************************************************************************
SUBROUTINE DELETE_NODE_NL(NL, INDEX) ! Deletes a node from the list of nodes by index
! *****************************************************************************
   TYPE(NODE_LIST), INTENT(INOUT) :: NL
   INTEGER, INTENT(IN) :: INDEX
   INTEGER :: LAST

   LAST = NL%NUM_NODES

   IF (NL%NUM_NODES .EQ. 0) RETURN ! Check if the list is empty
   IF (INDEX .LT. 1 .OR. INDEX .GT. LAST) RETURN ! Chek if the index is valid

   ! It simply copies the last node to the index to delete, and then decrements the number of nodes. 
   ! This is faster than shifting all nodes after the deleted one.
   ! Will not preserve the order but will test if order matters anywhere
   IF (INDEX .NE. LAST) THEN 
      NL%CROWN_FIRE(INDEX)        = NL%CROWN_FIRE(LAST)
      NL%IX(INDEX)                = NL%IX(LAST)
      NL%IY(INDEX)                = NL%IY(LAST)
      NL%BURNED(INDEX)            = NL%BURNED(LAST)
      NL%JUST_TAGGED(INDEX)       = NL%JUST_TAGGED(LAST)
      NL%CRITICAL_FLIN(INDEX)     = NL%CRITICAL_FLIN(LAST)
      NL%DPHIDX_LIMITED(INDEX)    = NL%DPHIDX_LIMITED(LAST)
      NL%DPHIDY_LIMITED(INDEX)    = NL%DPHIDY_LIMITED(LAST)
      NL%FLAME_LENGTH(INDEX)      = NL%FLAME_LENGTH(LAST)
      NL%FLIN_CANOPY(INDEX)       = NL%FLIN_CANOPY(LAST)
      NL%FLIN_DMS_SURFACE(INDEX)  = NL%FLIN_DMS_SURFACE(LAST)
      NL%FLIN_SURFACE(INDEX)      = NL%FLIN_SURFACE(LAST)
      NL%FMC(INDEX)               = NL%FMC(LAST)
      NL%HPUA_CANOPY(INDEX)       = NL%HPUA_CANOPY(LAST)
      NL%HPUA_SURFACE(INDEX)      = NL%HPUA_SURFACE(LAST)
      NL%IR(INDEX)                = NL%IR(LAST)
      NL%M1(INDEX)                = NL%M1(LAST)
      NL%M10(INDEX)               = NL%M10(LAST)
      NL%M100(INDEX)              = NL%M100(LAST)
      NL%MLH(INDEX)               = NL%MLH(LAST)
      NL%MLW(INDEX)               = NL%MLW(LAST)
      NL%NORMVECTORX(INDEX)       = NL%NORMVECTORX(LAST)
      NL%NORMVECTORY(INDEX)       = NL%NORMVECTORY(LAST)
      NL%PHIS_SURFACE(INDEX)      = NL%PHIS_SURFACE(LAST)
      NL%PHIW_CROWN(INDEX)        = NL%PHIW_CROWN(LAST)
      NL%PHIW_SURFACE(INDEX)      = NL%PHIW_SURFACE(LAST)
      NL%TIME_ADDED(INDEX)        = NL%TIME_ADDED(LAST)
      NL%TIME_OF_ARRIVAL(INDEX)   = NL%TIME_OF_ARRIVAL(LAST)
      NL%UX(INDEX)                = NL%UX(LAST)
      NL%UY(INDEX)                = NL%UY(LAST)
      NL%VELOCITY(INDEX)          = NL%VELOCITY(LAST)
      NL%VELOCITY_DMS(INDEX)         = NL%VELOCITY_DMS(LAST)
      NL%VS0(INDEX)                  = NL%VS0(LAST)
      NL%WD20_INTERP(INDEX)          = NL%WD20_INTERP(LAST)
      NL%WD20_NOW(INDEX)             = NL%WD20_NOW(LAST)
      NL%WS20_INTERP(INDEX)          = NL%WS20_INTERP(LAST)
      NL%WS20_NOW(INDEX)             = NL%WS20_NOW(LAST)
      NL%WSMF(INDEX)                 = NL%WSMF(LAST)
      NL%VELOCITY_DMS_SURFACE(INDEX) = NL%VELOCITY_DMS_SURFACE(LAST)
      NL%NEED_SLOPE_CALC(INDEX)   = NL%NEED_SLOPE_CALC(LAST)
      NL%PHISX(INDEX)             = NL%PHISX(LAST)
      NL%PHISY(INDEX)             = NL%PHISY(LAST)
      NL%UXOUSX(INDEX)            = NL%UXOUSX(LAST)
      NL%UYOUSY(INDEX)            = NL%UYOUSY(LAST)
      NL%NORMVECTORX_DMS(INDEX)   = NL%NORMVECTORX_DMS(LAST)
      NL%NORMVECTORY_DMS(INDEX)   = NL%NORMVECTORY_DMS(LAST)
      NL%VBACK(INDEX)             = NL%VBACK(LAST)
      NL%LOW(INDEX)               = NL%LOW(LAST)
      NL%IFBFM(INDEX)             = NL%IFBFM(LAST)
      NL%ADJ(INDEX)               = NL%ADJ(LAST)
      NL%TANSLP2(INDEX)           = NL%TANSLP2(LAST)
      NL%PHIP_OLD(INDEX)          = NL%PHIP_OLD(LAST)
      NL%DUMPME(INDEX)            = NL%DUMPME(LAST)
      NL%HRRPUA(INDEX)            = NL%HRRPUA(LAST)
      NL%TIME_SUPPRESSED(INDEX)   = NL%TIME_SUPPRESSED(LAST)
#ifdef _SUPPRESSION
      NL%SUPPRESSION_ADJUSTMENT_FACTOR(INDEX) = NL%SUPPRESSION_ADJUSTMENT_FACTOR(LAST)
      NL%SUPPRESSION_IDEG(INDEX)              = NL%SUPPRESSION_IDEG(LAST)
      NL%SDI(INDEX)                           = NL%SDI(LAST)
#endif
#ifdef _SMOKE
      NL%TIME_IGNITED(INDEX)           = NL%TIME_IGNITED(LAST)
      NL%TIME_EXTINGUISHED(INDEX)      = NL%TIME_EXTINGUISHED(LAST)
      NL%SMOKE_TFRAC(INDEX)            = NL%SMOKE_TFRAC(LAST)
      NL%QDOT_AVG(INDEX)               = NL%QDOT_AVG(LAST)
#endif
#ifdef _WUI
      NL%ELLIPSE_PARAMETERS(INDEX)     = NL%ELLIPSE_PARAMETERS(LAST)
      NL%BLDG_FUEL_MODEL(INDEX)        = NL%BLDG_FUEL_MODEL(LAST)
      NL%IBLDGFM(INDEX)                = NL%IBLDGFM(LAST)
      NL%SIGN_X(INDEX)                 = NL%SIGN_X(LAST)
      NL%SIGN_Y(INDEX)                 = NL%SIGN_Y(LAST)
      NL%BLDG_AREA(INDEX)              = NL%BLDG_AREA(LAST)
      NL%BLDG_NONBURNABLE_FRAC(INDEX)  = NL%BLDG_NONBURNABLE_FRAC(LAST)
      NL%BLDG_SEPARATION_DIST(INDEX)   = NL%BLDG_SEPARATION_DIST(LAST)
      NL%BLDG_FOOTPRINT_FRAC(INDEX)    = NL%BLDG_FOOTPRINT_FRAC(LAST)
      NL%RAD_DIST(INDEX)               = NL%RAD_DIST(LAST)
      NL%WIND_PROP(INDEX)              = NL%WIND_PROP(LAST)
      NL%HEAT_VALUE(INDEX)             = NL%HEAT_VALUE(LAST)
      NL%HRR_TRANSIENT(INDEX)          = NL%HRR_TRANSIENT(LAST)
      NL%ABSOLUTE_U(INDEX)             = NL%ABSOLUTE_U(LAST)
      NL%TOTAL_DFC_RECEIVED(INDEX)     = NL%TOTAL_DFC_RECEIVED(LAST)
      NL%TOTAL_RAD_RECEIVED(INDEX)     = NL%TOTAL_RAD_RECEIVED(LAST)
#endif
#ifdef _UMDSPOTTING
      NL%TAU_EMBERGEN(INDEX)           = NL%TAU_EMBERGEN(LAST)
      NL%LOCAL_EMBERGEN_DURATION(INDEX) = NL%LOCAL_EMBERGEN_DURATION(LAST)
      NL%T_START_SPOTTING(INDEX)        = NL%T_START_SPOTTING(LAST)
      NL%T_END_SPOTTING(INDEX)          = NL%T_END_SPOTTING(LAST)
#endif
   ENDIF

   NL%NUM_NODES = NL%NUM_NODES - 1

! *****************************************************************************
END SUBROUTINE DELETE_NODE_NL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_DLL_NODE_TO_SOA_TAGGED(C, NL, IDX)
! *****************************************************************************
! Full slot sync for tagged list after UNTAG_CELLS.

TYPE(NODE), INTENT(IN) :: C
TYPE(NODE_LIST), INTENT(INOUT) :: NL
INTEGER, INTENT(IN) :: IDX

   NL%CROWN_FIRE(IDX) = C%CROWN_FIRE
   NL%IX(IDX) = C%IX
   NL%IY(IDX) = C%IY
   NL%BURNED(IDX) = C%BURNED
   NL%JUST_TAGGED(IDX) = C%JUST_TAGGED
   NL%CRITICAL_FLIN(IDX) = C%CRITICAL_FLIN
   NL%DPHIDX_LIMITED(IDX) = C%DPHIDX_LIMITED
   NL%DPHIDY_LIMITED(IDX) = C%DPHIDY_LIMITED
   NL%FLAME_LENGTH(IDX) = C%FLAME_LENGTH
   NL%FLIN_CANOPY(IDX) = C%FLIN_CANOPY
   NL%FLIN_DMS_SURFACE(IDX) = C%FLIN_DMS_SURFACE
   NL%FLIN_SURFACE(IDX) = C%FLIN_SURFACE
   NL%FMC(IDX) = C%FMC
   NL%HPUA_CANOPY(IDX) = C%HPUA_CANOPY
   NL%HPUA_SURFACE(IDX) = C%HPUA_SURFACE
   NL%IR(IDX) = C%IR
   NL%M1(IDX) = C%M1
   NL%M10(IDX) = C%M10
   NL%M100(IDX) = C%M100
   NL%MLH(IDX) = C%MLH
   NL%MLW(IDX) = C%MLW
   NL%NORMVECTORX(IDX) = C%NORMVECTORX
   NL%NORMVECTORY(IDX) = C%NORMVECTORY
   NL%PHIS_SURFACE(IDX) = C%PHIS_SURFACE
   NL%PHIW_CROWN(IDX) = C%PHIW_CROWN
   NL%PHIW_SURFACE(IDX) = C%PHIW_SURFACE
   NL%TIME_ADDED(IDX) = C%TIME_ADDED
   NL%TIME_OF_ARRIVAL(IDX) = C%TIME_OF_ARRIVAL
   NL%UX(IDX) = C%UX
   NL%UY(IDX) = C%UY
   NL%VELOCITY(IDX) = C%VELOCITY
   NL%VELOCITY_DMS(IDX) = C%VELOCITY_DMS
   NL%VS0(IDX) = C%VS0
   NL%WD20_INTERP(IDX) = C%WD20_INTERP
   NL%WD20_NOW(IDX) = C%WD20_NOW
   NL%WS20_INTERP(IDX) = C%WS20_INTERP
   NL%WS20_NOW(IDX) = C%WS20_NOW
   NL%WSMF(IDX) = C%WSMF
   NL%VELOCITY_DMS_SURFACE(IDX) = C%VELOCITY_DMS_SURFACE
   NL%NEED_SLOPE_CALC(IDX) = C%NEED_SLOPE_CALC
   NL%PHISX(IDX) = C%PHISX
   NL%PHISY(IDX) = C%PHISY
   NL%UXOUSX(IDX) = C%UXOUSX
   NL%UYOUSY(IDX) = C%UYOUSY
   NL%NORMVECTORX_DMS(IDX) = C%NORMVECTORX_DMS
   NL%NORMVECTORY_DMS(IDX) = C%NORMVECTORY_DMS
   NL%VBACK(IDX) = C%VBACK
   NL%LOW(IDX) = C%LOW
   NL%IFBFM(IDX) = C%IFBFM
   NL%ADJ(IDX) = C%ADJ
   NL%TANSLP2(IDX) = C%TANSLP2
   NL%PHIP_OLD(IDX) = C%PHIP_OLD
   NL%DUMPME(IDX) = C%DUMPME
   NL%HRRPUA(IDX) = C%HRRPUA
   NL%TIME_SUPPRESSED(IDX) = C%TIME_SUPPRESSED
#ifdef _SUPPRESSION
   NL%SUPPRESSION_ADJUSTMENT_FACTOR(IDX) = C%SUPPRESSION_ADJUSTMENT_FACTOR
   NL%SUPPRESSION_IDEG(IDX) = C%SUPPRESSION_IDEG
   NL%SDI(IDX) = C%SDI
#endif
#ifdef _SMOKE
   NL%TIME_IGNITED(IDX) = C%TIME_IGNITED
   NL%TIME_EXTINGUISHED(IDX) = C%TIME_EXTINGUISHED
   NL%SMOKE_TFRAC(IDX) = C%SMOKE_TFRAC
   NL%QDOT_AVG(IDX) = C%QDOT_AVG
#endif
#ifdef _WUI
   NL%BLDG_FUEL_MODEL(IDX) = C%BLDG_FUEL_MODEL
   NL%IBLDGFM(IDX) = C%IBLDGFM
   NL%SIGN_X(IDX) = C%SIGN_X
   NL%SIGN_Y(IDX) = C%SIGN_Y
   NL%BLDG_AREA(IDX) = C%BLDG_AREA
   NL%BLDG_NONBURNABLE_FRAC(IDX) = C%BLDG_NONBURNABLE_FRAC
   NL%BLDG_SEPARATION_DIST(IDX) = C%BLDG_SEPARATION_DIST
   NL%BLDG_FOOTPRINT_FRAC(IDX) = C%BLDG_FOOTPRINT_FRAC
   NL%RAD_DIST(IDX) = C%RAD_DIST
   NL%WIND_PROP(IDX) = C%WIND_PROP
   NL%HEAT_VALUE(IDX) = C%HEAT_VALUE
   NL%HRR_TRANSIENT(IDX) = C%HRR_TRANSIENT
   NL%ABSOLUTE_U(IDX) = C%AbsOLUTE_U
   NL%TOTAL_DFC_RECEIVED(IDX) = C%TOTAL_DFC_RECEIVED
   NL%TOTAL_RAD_RECEIVED(IDX) = C%TOTAL_RAD_RECEIVED
#endif
#ifdef _UMDSPOTTING
   NL%TAU_EMBERGEN(IDX) = C%TAU_EMBERGEN
   NL%LOCAL_EMBERGEN_DURATION(IDX) = C%LOCAL_EMBERGEN_DURATION
   NL%T_START_SPOTTING(IDX) = C%T_START_SPOTTING
   NL%T_END_SPOTTING(IDX) = C%T_END_SPOTTING
#endif

! *****************************************************************************
END SUBROUTINE SYNC_DLL_NODE_TO_SOA_TAGGED
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_DLL_TO_SOA_SURF(L, NL)
! *****************************************************************************
! Bridge sync: copies DLL fields to SoA before calling SURFACE_SPREAD_RATE_NL.
! To be removed once full dual-write is implemented.

TYPE(DLL), INTENT(IN) :: L
TYPE(NODE_LIST), INTENT(INOUT) :: NL
INTEGER :: I
TYPE(NODE), POINTER :: C

NL%NUM_NODES = L%NUM_NODES
C => L%HEAD

DO I = 1, L%NUM_NODES
   NL%IX(I)          = C%IX
   NL%IY(I)          = C%IY
   NL%IFBFM(I)       = C%IFBFM
   NL%M1(I)          = C%M1
   NL%M10(I)         = C%M10
   NL%M100(I)        = C%M100
   NL%MLH(I)         = C%MLH
   NL%MLW(I)         = C%MLW
   NL%WSMF(I)        = C%WSMF
   NL%TANSLP2(I)     = C%TANSLP2
   NL%ADJ(I)         = C%ADJ
#ifdef _SUPPRESSION
   NL%SUPPRESSION_ADJUSTMENT_FACTOR(I) = C%SUPPRESSION_ADJUSTMENT_FACTOR
#endif
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE SYNC_DLL_TO_SOA_SURF
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_SOA_TO_DLL_SURF(NL, L)
! *****************************************************************************
! Bridge sync: copies SoA output fields back to DLL after SURFACE_SPREAD_RATE_NL.
! To be removed once full dual-write is implemented.

TYPE(NODE_LIST), INTENT(IN) :: NL
TYPE(DLL), INTENT(INOUT) :: L
INTEGER :: I
TYPE(NODE), POINTER :: C

C => L%HEAD

DO I = 1, L%NUM_NODES
   C%IR                = NL%IR(I)
   C%PHIW_SURFACE      = NL%PHIW_SURFACE(I)
   C%PHIS_SURFACE      = NL%PHIS_SURFACE(I)
   C%VS0               = NL%VS0(I)
   C%VELOCITY_DMS_SURFACE = NL%VELOCITY_DMS_SURFACE(I)
   C%HPUA_SURFACE      = NL%HPUA_SURFACE(I)
   C%FLIN_DMS_SURFACE  = NL%FLIN_DMS_SURFACE(I)
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE SYNC_SOA_TO_DLL_SURF
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_DLL_TO_SOA_CROWN(L, NL)
! *****************************************************************************
! Bridge sync: copies DLL fields to SoA before calling CROWN_SPREAD_RATE_NL.
! To be removed once full dual-write is implemented.

TYPE(DLL), INTENT(IN) :: L
TYPE(NODE_LIST), INTENT(INOUT) :: NL
INTEGER :: I
TYPE(NODE), POINTER :: C

NL%NUM_NODES = L%NUM_NODES
C => L%HEAD

DO I = 1, L%NUM_NODES
   NL%IX(I)               = C%IX
   NL%IY(I)               = C%IY
   NL%M1(I)               = C%M1
   NL%FMC(I)              = C%FMC
   NL%WS20_NOW(I)         = C%WS20_NOW
   NL%FLIN_DMS_SURFACE(I) = C%FLIN_DMS_SURFACE
   NL%FLIN_SURFACE(I)     = C%FLIN_SURFACE
   NL%VS0(I)              = C%VS0
   NL%CRITICAL_FLIN(I)     = C%CRITICAL_FLIN
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE SYNC_DLL_TO_SOA_CROWN
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_SOA_TO_DLL_CROWN(NL, L)
! *****************************************************************************
! Bridge sync: copies SoA output fields back to DLL after CROWN_SPREAD_RATE_NL.
! To be removed once full dual-write is implemented.

TYPE(NODE_LIST), INTENT(IN) :: NL
TYPE(DLL), INTENT(INOUT) :: L
INTEGER :: I
TYPE(NODE), POINTER :: C

C => L%HEAD

DO I = 1, L%NUM_NODES
   C%HPUA_CANOPY   = NL%HPUA_CANOPY(I)
   C%CRITICAL_FLIN = NL%CRITICAL_FLIN(I)
   C%CROWN_FIRE    = NL%CROWN_FIRE(I)
   C%PHIW_CROWN    = NL%PHIW_CROWN(I)
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE SYNC_SOA_TO_DLL_CROWN
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_DLL_TO_SOA_SURF_SLOT(C, NL, IDX)
! *****************************************************************************
! Bridge sync: copies a single DLL node's fields to a single SoA slot.
! Used by call site 4 (single-node mode, newly tagged cells).

TYPE(NODE), POINTER, INTENT(IN)    :: C
TYPE(NODE_LIST),      INTENT(INOUT) :: NL
INTEGER,              INTENT(IN)    :: IDX

NL%IX(IDX)          = C%IX
NL%IY(IDX)          = C%IY
NL%IFBFM(IDX)       = C%IFBFM
NL%M1(IDX)          = C%M1
NL%M10(IDX)         = C%M10
NL%M100(IDX)        = C%M100
NL%MLH(IDX)         = C%MLH
NL%MLW(IDX)         = C%MLW
NL%WSMF(IDX)        = C%WSMF
NL%TANSLP2(IDX)     = C%TANSLP2
NL%ADJ(IDX)         = C%ADJ
#ifdef _SUPPRESSION
NL%SUPPRESSION_ADJUSTMENT_FACTOR(IDX) = C%SUPPRESSION_ADJUSTMENT_FACTOR
#endif

! *****************************************************************************
END SUBROUTINE SYNC_DLL_TO_SOA_SURF_SLOT
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_SOA_TO_DLL_SURF_SLOT(NL, IDX, C)
! *****************************************************************************
! Bridge sync: copies a single SoA slot's output fields back to a DLL node.

TYPE(NODE_LIST), INTENT(IN)    :: NL
INTEGER,         INTENT(IN)    :: IDX
TYPE(NODE), POINTER, INTENT(INOUT) :: C

C%IR                = NL%IR(IDX)
C%PHIW_SURFACE      = NL%PHIW_SURFACE(IDX)
C%PHIS_SURFACE      = NL%PHIS_SURFACE(IDX)
C%VS0               = NL%VS0(IDX)
C%VELOCITY_DMS_SURFACE = NL%VELOCITY_DMS_SURFACE(IDX)
C%HPUA_SURFACE      = NL%HPUA_SURFACE(IDX)
C%FLIN_DMS_SURFACE  = NL%FLIN_DMS_SURFACE(IDX)

! *****************************************************************************
END SUBROUTINE SYNC_SOA_TO_DLL_SURF_SLOT
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_DLL_TO_SOA_CROWN_SLOT(C, NL, IDX)
! *****************************************************************************
! Bridge sync: copies a single DLL node's crown fields to a single SoA slot.

TYPE(NODE), POINTER, INTENT(IN)    :: C
TYPE(NODE_LIST),      INTENT(INOUT) :: NL
INTEGER,              INTENT(IN)    :: IDX

NL%IX(IDX)               = C%IX
NL%IY(IDX)               = C%IY
NL%M1(IDX)               = C%M1
NL%FMC(IDX)              = C%FMC
NL%WS20_NOW(IDX)         = C%WS20_NOW
NL%FLIN_DMS_SURFACE(IDX) = C%FLIN_DMS_SURFACE
NL%FLIN_SURFACE(IDX)     = C%FLIN_SURFACE
NL%VS0(IDX)              = C%VS0
NL%CRITICAL_FLIN(IDX)    = C%CRITICAL_FLIN

! *****************************************************************************
END SUBROUTINE SYNC_DLL_TO_SOA_CROWN_SLOT
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_SOA_TO_DLL_CROWN_SLOT(NL, IDX, C)
! *****************************************************************************
! Bridge sync: copies a single SoA slot's crown output fields back to a DLL node.

TYPE(NODE_LIST), INTENT(IN)    :: NL
INTEGER,         INTENT(IN)    :: IDX
TYPE(NODE), POINTER, INTENT(INOUT) :: C

C%HPUA_CANOPY   = NL%HPUA_CANOPY(IDX)
C%CRITICAL_FLIN = NL%CRITICAL_FLIN(IDX)
C%CROWN_FIRE    = NL%CROWN_FIRE(IDX)
C%PHIW_CROWN    = NL%PHIW_CROWN(IDX)

! *****************************************************************************
END SUBROUTINE SYNC_SOA_TO_DLL_CROWN_SLOT
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_SOA_TO_DLL_NORMAL(NL, L)
! *****************************************************************************
! Bridge sync: copies SoA normal vector and PHIP_OLD fields back to DLL.
! To be removed once full dual-write is implemented.

TYPE(NODE_LIST), INTENT(IN)    :: NL
TYPE(DLL),       INTENT(INOUT) :: L
INTEGER :: I
TYPE(NODE), POINTER :: C

C => L%HEAD

DO I = 1, L%NUM_NODES
   C%NORMVECTORX = NL%NORMVECTORX(I)
   C%NORMVECTORY = NL%NORMVECTORY(I)
   C%PHIP_OLD    = NL%PHIP_OLD(I)
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE SYNC_SOA_TO_DLL_NORMAL
! *****************************************************************************

! *****************************************************************************
SUBROUTINE SYNC_SOA_TO_DLL_UXUY(NL, L)
! *****************************************************************************
! Bridge sync: copies SoA output fields from UX_AND_UY_ELLIPTICAL_NL back to DLL.
! To be removed once full dual-write is implemented.

TYPE(NODE_LIST), INTENT(IN)    :: NL
TYPE(DLL),       INTENT(INOUT) :: L
INTEGER :: I
TYPE(NODE), POINTER :: C

C => L%HEAD

DO I = 1, L%NUM_NODES
   C%UX              = NL%UX(I)
   C%UY              = NL%UY(I)
   C%VELOCITY        = NL%VELOCITY(I)
   C%VELOCITY_DMS    = NL%VELOCITY_DMS(I)
   C%VBACK           = NL%VBACK(I)
   C%LOW             = NL%LOW(I)
   C%NORMVECTORX_DMS = NL%NORMVECTORX_DMS(I)
   C%NORMVECTORY_DMS = NL%NORMVECTORY_DMS(I)
   C%FLIN_SURFACE    = NL%FLIN_SURFACE(I)
   C%FLIN_CANOPY     = NL%FLIN_CANOPY(I)
   C%PHISX           = NL%PHISX(I)
   C%PHISY           = NL%PHISY(I)
   C%UXOUSX          = NL%UXOUSX(I)
   C%UYOUSY          = NL%UYOUSY(I)
   C%NEED_SLOPE_CALC = NL%NEED_SLOPE_CALC(I)
   C%ABSOLUTE_U      = NL%ABSOLUTE_U(I)
   C%SIGN_X          = NL%SIGN_X(I)
   C%SIGN_Y          = NL%SIGN_Y(I)
   C%HEAT_VALUE      = NL%HEAT_VALUE(I)
   C%TOTAL_DFC_RECEIVED = NL%TOTAL_DFC_RECEIVED(I)
   C%TOTAL_RAD_RECEIVED = NL%TOTAL_RAD_RECEIVED(I)
#ifdef _UMDSPOTTING
   C%LOCAL_EMBERGEN_DURATION = NL%LOCAL_EMBERGEN_DURATION(I)
#endif
   C => C%NEXT
ENDDO

! *****************************************************************************
END SUBROUTINE SYNC_SOA_TO_DLL_UXUY
! *****************************************************************************

! *****************************************************************************
SUBROUTINE DELETE_NODE(DL2, CURRENT)
! *****************************************************************************

TYPE(DLL), INTENT(INOUT) :: DL2
TYPE(NODE), POINTER, INTENT(INOUT) :: CURRENT
TYPE(NODE), POINTER :: NP

!IF (.NOT. ASSOCIATED(CURRENT)) THEN
!   WRITE(*,*) 'EXITING BECAUSE CURRENT NOT ASSOCIATED'
!   RETURN
!ENDIF

NP => CURRENT
CONTINUE
IF (ASSOCIATED(CURRENT%PREV) .AND. ASSOCIATED(CURRENT%NEXT)) THEN !Deleting intermediate node
   CURRENT%PREV%NEXT => CURRENT%NEXT
   CURRENT%NEXT%PREV => CURRENT%PREV
   CURRENT => CURRENT%PREV
CONTINUE
ELSE IF (ASSOCIATED(CURRENT%PREV) .AND. (.NOT. ASSOCIATED(CURRENT%NEXT))) THEN ! Deleting tail node
   CURRENT%PREV%NEXT => NULL()
   CURRENT => CURRENT%PREV
   DL2%TAIL => CURRENT
CONTINUE
ELSE IF (.NOT. ASSOCIATED(CURRENT%PREV) .AND. ASSOCIATED(CURRENT%NEXT)) THEN ! Deleting head node
   DL2%HEAD => CURRENT%NEXT
   CURRENT => DL2%HEAD
   CURRENT%PREV => NULL()
CONTINUE
!ELSE
!   CONTINUE
ENDIF

DEALLOCATE(NP)
DL2%NUM_NODES = DL2%NUM_NODES - 1

! *****************************************************************************
END SUBROUTINE DELETE_NODE
! ***************************************************************************** 

! *****************************************************************************
SUBROUTINE TIDY(DL2)
! *****************************************************************************

TYPE(DLL), INTENT(INOUT) :: DL2
TYPE(NODE), POINTER :: CURRENT, LAST

!INTEGER :: COUNT

!COUNT = 0 

IF (DL2%NUM_NODES .EQ. 1) THEN
   DEALLOCATE(DL2%HEAD)
ELSE
   CURRENT => DL2%HEAD
   DO
      LAST => CURRENT
      CURRENT => CURRENT%NEXT
      IF (ASSOCIATED(LAST)) THEN
!         COUNT = COUNT + 1
         DEALLOCATE(LAST)
      END IF
      IF (ASSOCIATED(CURRENT, DL2%TAIL)) THEN
!         COUNT = COUNT + 1
         DEALLOCATE(CURRENT)
         EXIT
      ENDIF
   ENDDO
ENDIF
! *****************************************************************************
END SUBROUTINE TIDY
! *****************************************************************************

! *****************************************************************************
SUBROUTINE locate(xx,n,x,j)
! *****************************************************************************
! Given an array xx(1:n), and given a value x, returns a value j such that x is between
! xx(j) and xx(j+1). xx(1:n) must be monotonic, either increasing or decreasing. j=0
! or j=n is returned to indicate that x is out of range.

INTEGER j,n
REAL :: x,xx(n)
INTEGER jl,jm,ju
jl=0 !Initialize lower
ju=n+1 !and upper limits.
 10 if(ju-jl.gt.1)then !If we are not yet done,
       jm=(ju+jl)/2 !compute a midpoint,
       if((xx(n).ge.xx(1)).eqv.(x.ge.xx(jm)))then
          jl=jm !and replace either the lower limit
       else
          ju=jm !or the upper limit, as appropriate.
       endif
       goto 10 !Repeat until
    endif !the test condition 10 is satisfied.
      
if(x.eq.xx(1))then !Then set the output
   j=1
else if(x.eq.xx(n))then
   j=n-1
else
   j=jl
endif

! *****************************************************************************
END SUBROUTINE LOCATE
! *****************************************************************************

!******************************************************************************
SUBROUTINE SUNRISE_SUNSET_CALCS(LON_DEG,LAT_DEG,YEAR,HOUR_OF_YEAR)
!******************************************************************************

REAL, INTENT(IN) :: LON_DEG, LAT_DEG
INTEGER, INTENT(IN) :: YEAR, HOUR_OF_YEAR
LOGICAL :: LEAPYEAR
INTEGER :: DAY_OF_YEAR, HOUR_OF_DAY
REAL :: DAYS_PER_YEAR, GAMMA, EQTIME, COSPIMTHETA, DECL, HA, HA_SUNRISE, LAT_RAD, LON_RAD, PHI, THETA, TST, &
        SUNRISE_MIN_UTC, SUNRISE_H_UTC, SUNSET_MIN_UTC, HA_SUNSET, SUNSET_H_UTC

LON_RAD = LON_DEG * PI / 180.
LAT_RAD = LAT_DEG * PI / 180.

LEAPYEAR = .FALSE.
IF (MOD(YEAR,4) .EQ. 0) LEAPYEAR = .TRUE.
DAYS_PER_YEAR = 365.
IF (LEAPYEAR) DAYS_PER_YEAR = 366.

DAY_OF_YEAR = 1 + FLOOR(REAL(HOUR_OF_YEAR) / 24.)
HOUR_OF_DAY = HOUR_OF_YEAR - (DAY_OF_YEAR - 1) * 24
GAMMA = 2.0 * (PI/DAYS_PER_YEAR) * (DAY_OF_YEAR - 1)

EQTIME = 229.18 * ( 0.000075 + 0.001868*COS(GAMMA) - 0.032077*SIN(GAMMA) - 0.014615*COS(2.*GAMMA) - 0.040849*SIN(2.*GAMMA) )
DECL   = 0.006918 - 0.399912*COS(GAMMA) + 0.070257*SIN(GAMMA) - 0.006758*COS(2.*GAMMA) + 0.000907*SIN(2.*GAMMA) - 0.002697*COS(3.*GAMMA) + 0.00148*SIN(3.*GAMMA)

! Begin part not needed for sunrise / sunset calcs:
TST = REAL(HOUR_OF_DAY) * 60. + EQTIME + 4. * LON_DEG
HA = 0.25 * TST - 180.
PHI = ACOS(SIN(LAT_RAD)*SIN(DECL)+COS(LAT_RAD)*COS(DECL)*COS(HA*PI/180))
COSPIMTHETA = (SIN(LAT_RAD)*COS(PHI) - SIN(DECL)) / (COS(LAT_RAD)*SIN(PHI))
THETA = PI - ACOS(COSPIMTHETA)
! End part not needed for sunrise / sunset calcs

HA_SUNRISE = ACOS( COS(90.833*PI/180) / (COS(LAT_RAD)*COS(DECL)) -TAN(LAT_RAD)*TAN(DECL) )
SUNRISE_MIN_UTC = 720. - 4.*(LON_DEG + HA_SUNRISE*180./PI) - EQTIME
SUNRISE_H_UTC = SUNRISE_MIN_UTC / 60.

HA_SUNSET = -HA_SUNRISE
SUNSET_MIN_UTC = 720. - 4.*(LON_DEG + HA_SUNSET*180./PI) - EQTIME
SUNSET_H_UTC = SUNSET_MIN_UTC / 60.

SUNRISE_HOUR = SUNRISE_H_UTC ! Scope is global
SUNSET_HOUR  = SUNSET_H_UTC ! Scope is global

! *****************************************************************************
END SUBROUTINE SUNRISE_SUNSET_CALCS
!******************************************************************************

! *****************************************************************************
SUBROUTINE SHUTDOWN
! *****************************************************************************

INTEGER :: I, IERR
CHARACTER(4) :: FOUR
LOGICAL :: LOPEN
CHARACTER(400) :: FN

IF (NUM_TIME_AT_BURNED_ACRES .GT. 0) THEN
   DO I = 0, NPROC - 1
      WRITE(FOUR, '(I4.4)') I
      FN = TRIM(OUTPUTS_DIRECTORY) // 'burned-acres-timings_' // FOUR // '.csv'
      INQUIRE(UNIT=LUBAT+I,OPENED=LOPEN)
      IF (LOPEN) CLOSE(LUBAT+I) 
   ENDDO
ENDIF

IF (PROCESS_TIMED_LOCATIONS) THEN
   DO I = 0, NPROC - 1
      WRITE(FOUR, '(I4.4)') I
      FN = TRIM(OUTPUTS_DIRECTORY) // 'timed-locations-events_' // FOUR // '.csv'
      INQUIRE(UNIT=LUTASL+I,OPENED=LOPEN)
      IF (LOPEN) CLOSE(LUTASL+I)
   ENDDO
ENDIF

IF (NPROC .GT. 1) THEN
   CALL MPI_WIN_FREE(WIN_WS           )
   CALL MPI_WIN_FREE(WIN_WD           )
   CALL MPI_WIN_FREE(WIN_M1           )
   CALL MPI_WIN_FREE(WIN_M10          )
   CALL MPI_WIN_FREE(WIN_M100         )
   IF (USE_ERC) THEN
      CALL MPI_WIN_FREE(WIN_ERC       )
      CALL MPI_WIN_FREE(WIN_IGNFAC    )
   ENDIF
   CALL MPI_WIN_FREE(WIN_MLH           )
   CALL MPI_WIN_FREE(WIN_MLW           )
   CALL MPI_WIN_FREE(WIN_MFOL          )
   CALL MPI_WIN_FREE(WIN_ASP           )
   CALL MPI_WIN_FREE(WIN_CBH           )
   CALL MPI_WIN_FREE(WIN_CBD           )
   CALL MPI_WIN_FREE(WIN_CC            )
   CALL MPI_WIN_FREE(WIN_CH            )
   IF (MODE .NE. 2) CALL MPI_WIN_FREE(WIN_DEM)
   CALL MPI_WIN_FREE(WIN_FBFM          )
   CALL MPI_WIN_FREE(WIN_SLP           )
   CALL MPI_WIN_FREE(WIN_ADJ           )
   IF (MODE .NE. 2) CALL MPI_WIN_FREE(WIN_PHI0)
   CALL MPI_WIN_FREE(WIN_WAF           )
   CALL MPI_WIN_FREE(WIN_OMCOSSLPRAD   )
   CALL MPI_WIN_FREE(WIN_ISNONBURNABLE )

   IF (USE_POPULATION_DENSITY) CALL MPI_WIN_FREE(WIN_POPULATION_DENSITY)
   IF (USE_REAL_ESTATE_VALUE ) CALL MPI_WIN_FREE(WIN_REAL_ESTATE_VALUE )
   IF (USE_LAND_VALUE        ) CALL MPI_WIN_FREE(WIN_LAND_VALUE        )

   CALL MPI_WIN_FREE(WIN_STATS_X                         )
   CALL MPI_WIN_FREE(WIN_STATS_Y                         )
   CALL MPI_WIN_FREE(WIN_STATS_ASTOP                     )
   CALL MPI_WIN_FREE(WIN_STATS_TSTOP                     )   
   CALL MPI_WIN_FREE(WIN_STATS_SURFACE_FIRE_AREA         )
   CALL MPI_WIN_FREE(WIN_STATS_CROWN_FIRE_AREA           )
   CALL MPI_WIN_FREE(WIN_STATS_FIRE_VOLUME               )
   CALL MPI_WIN_FREE(WIN_STATS_AFFECTED_POPULATION       )
   CALL MPI_WIN_FREE(WIN_STATS_AFFECTED_REAL_ESTATE_VALUE)
   CALL MPI_WIN_FREE(WIN_STATS_AFFECTED_LAND_VALUE       )
   CALL MPI_WIN_FREE(WIN_STATS_FINAL_CONTAINMENT_FRAC    )
   CALL MPI_WIN_FREE(WIN_STATS_NEMBERS                   )
   CALL MPI_WIN_FREE(WIN_STATS_ICASE                     )
   CALL MPI_WIN_FREE(WIN_STATS_IWX_BAND_START            )
   CALL MPI_WIN_FREE(WIN_STATS_IWX_SERIAL_BAND           )
   CALL MPI_WIN_FREE(WIN_STATS_SIMULATION_TSTOP_HOURS    )
   CALL MPI_WIN_FREE(WIN_STATS_WALL_CLOCK_TIME           )
ENDIF

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

! Dump timings:
CALL SYSTEM_CLOCK(IT_STOP)
TIMINGS(IRANK_HOST+1,1) = REAL(IT_STOP - IT_START) / REAL(CLOCK_COUNT_RATE)
CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)
IF (DUMP_TIMINGS .AND. IRANK_HOST .EQ. 0) CALL WRITE_TIMINGS_TO_DISK

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)
IF (NPROC .GT. 1) CALL MPI_WIN_FREE(WIN_TIMINGS)

CALL MPI_BARRIER(MPI_COMM_WORLD, IERR)

CALL MPI_FINALIZE(IERR)

IF (IRANK_WORLD .EQ. 0) WRITE(*,*) 'End of simulation reached successfully. Shutting down.'

! *****************************************************************************
END SUBROUTINE SHUTDOWN
! *****************************************************************************

! *****************************************************************************
SUBROUTINE ERC_IGNITION_FACTOR (ERC, IGNFAC, IB1, IB2)
! *****************************************************************************

TYPE (RASTER_TYPE), INTENT(IN) :: ERC
TYPE (RASTER_TYPE) :: IGNFAC
INTEGER, INTENT(IN) :: IB1, IB2
INTEGER :: IBAND, IROW, ICOL
REAL :: ERCVAL, EXPONENT

IGNFAC%BYTEORDER     = ERC%BYTEORDER
IGNFAC%LAYOUT        = ERC%LAYOUT
IGNFAC%NROWS         = ERC%NROWS
IGNFAC%NCOLS         = ERC%NCOLS
IGNFAC%NBANDS        = ERC%NBANDS
IGNFAC%NBITS         = ERC%NBITS
IGNFAC%BANDROWBYTES  = ERC%BANDROWBYTES
IGNFAC%TOTALROWBYTES = ERC%TOTALROWBYTES
IGNFAC%PIXELTYPE     = ERC%PIXELTYPE
IGNFAC%ULXMAP        = ERC%ULXMAP
IGNFAC%ULYMAP        = ERC%ULYMAP
IGNFAC%XDIM          = ERC%XDIM
IGNFAC%YDIM          = ERC%YDIM
IGNFAC%NODATA_VALUE  = ERC%NODATA_VALUE
IGNFAC%CELLSIZE      = ERC%CELLSIZE
IGNFAC%XLLCORNER     = ERC%XLLCORNER
IGNFAC%YLLCORNER     = ERC%YLLCORNER

IF (ERC_IS_PLIGNRATE) THEN
   DO IBAND = IB1, IB2
      DO IROW = 1, ERC%NROWS
      DO ICOL = 1, ERC%NCOLS
         IGNFAC%R4(ICOL,IROW,IBAND) = MAX(PLIGNRATE_MIN, ERC%R4(ICOL,IROW,IBAND))
      ENDDO
      ENDDO
   ENDDO
ELSE
   DO IBAND = IB1, IB2
      DO IROW = 1, ERC%NROWS
      DO ICOL = 1, ERC%NCOLS
         ERCVAL = MIN( MAX(ERC%R4(ICOL,IROW,IBAND),0.),100.0)
         EXPONENT = 0.02768 * ERCVAL - 0.2333
         IGNFAC%R4(ICOL,IROW,IBAND) = MIN( MAX ( 2.92E-3 * 10**EXPONENT, 1E-3 ), 1E0)
      ENDDO
      ENDDO
   ENDDO
ENDIF

! *****************************************************************************
END SUBROUTINE ERC_IGNITION_FACTOR
! *****************************************************************************

! *****************************************************************************
REAL FUNCTION ERFINV(X)
! *****************************************************************************

REAL, INTENT(IN) :: X
REAL, PARAMETER :: HALFSQRTPI = 0.88622692545
REAL :: X2, X4, X6, X8
REAL, PARAMETER :: C1 = 1.000000000
REAL, PARAMETER :: C2 = 0.261799388
REAL, PARAMETER :: C3 = 0.143931731
REAL, PARAMETER :: C4 = 0.097663620
REAL, PARAMETER :: C5 = 0.073299079
REAL, PARAMETER :: C6 = 0.058372501

!ERFINV = 0.5*SQRT(PI)*(C1*X + C2*X**3 + C3*X**5 + C4*X**7 + C5*X**9 + C6*X**11) 

X2  = X  * X
X4  = X2 * X2
X6  = X4 * X2
X8  = X6 * X2
!X10 = X8 * X2

!ERFINV = HALFSQRTPI * X * (C1 + C2*X2 + C3*X4 + C4*X6 + C5*X8 + C6*X10) 

ERFINV = HALFSQRTPI * X * (C1 + C2*X2 + C3*X4 + C4*X6 + C5*X8) 

! *****************************************************************************
END FUNCTION ERFINV
! *****************************************************************************

! *****************************************************************************
CHARACTER(16) FUNCTION HOUR_OF_YEAR_TO_TIMESTAMP(YEAR, HOUR_OF_YEAR)
! *****************************************************************************

INTEGER, INTENT(IN) :: YEAR
INTEGER, INTENT(IN) :: HOUR_OF_YEAR
INTEGER :: I, HOUR_OF_MONTH, DAY_OF_MONTH, HOUR_OF_DAY, MONTH
INTEGER, DIMENSION(12) :: DAYS_PER_MONTH=(/ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 /), &
                          MONTH_BEGIN_HOUR, MONTH_END_HOUR
LOGICAL :: FOUND
CHARACTER(16) :: TIMESTAMP

IF ( (MODULO(YEAR,4) .EQ. 0 .AND. MODULO(YEAR,100) .NE. 0) .OR. MODULO(YEAR,400) .EQ. 0 ) DAYS_PER_MONTH(2)=29

MONTH_BEGIN_HOUR(1) = 0
MONTH_END_HOUR  (1) = DAYS_PER_MONTH(1) * 24
DO I = 2, 12
   MONTH_BEGIN_HOUR(I) = MONTH_END_HOUR  (I-1)
   MONTH_END_HOUR  (I) = MONTH_BEGIN_HOUR(I)   + DAYS_PER_MONTH(I) * 24
ENDDO

FOUND = .FALSE.
MONTH = 1
DO I = 1, 12
   IF (FOUND) CYCLE
   IF (HOUR_OF_YEAR .GE. MONTH_BEGIN_HOUR(I) .AND. HOUR_OF_YEAR .LT. MONTH_END_HOUR(I) ) THEN
      FOUND = .TRUE.
      MONTH = I
   ENDIF
ENDDO

HOUR_OF_MONTH = HOUR_OF_YEAR - MONTH_BEGIN_HOUR(MONTH)
DAY_OF_MONTH  = 1 + HOUR_OF_MONTH / 24
HOUR_OF_DAY   = MODULO( HOUR_OF_MONTH,24)

WRITE( TIMESTAMP,  '(I4.4,"-",I2.2,"-",I2.2," ",I2.2,":00")') YEAR, MONTH, DAY_OF_MONTH, HOUR_OF_DAY

HOUR_OF_YEAR_TO_TIMESTAMP = TIMESTAMP

! *****************************************************************************
END FUNCTION HOUR_OF_YEAR_TO_TIMESTAMP
! *****************************************************************************

! *****************************************************************************
END MODULE ELMFIRE_SUBS
! *****************************************************************************
