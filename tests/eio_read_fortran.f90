! Read an Elmer mesh through eiof, the Fortran binding.
!
! This is the binding Elmer's solver actually linked against, so building it
! without exercising it would leave the more important of the two libraries
! untested. It reads a mesh checked into the repository rather than one
! written earlier in the same test run, so that it does not depend on another
! test having gone first, and so that a reader agreeing only with its own
! writer cannot pass.

PROGRAM eio_read_fortran
  USE, INTRINSIC :: ISO_C_BINDING
  USE EIOFortranAPI
  IMPLICIT NONE

  INTEGER, PARAMETER :: EXPECT_NODES = 4
  INTEGER, PARAMETER :: EXPECT_ELEMENTS = 1
  INTEGER, PARAMETER :: EXPECT_BOUNDARY = 4

  CHARACTER(LEN=1024) :: argdir
  CHARACTER(kind=c_char), ALLOCATABLE :: cdir(:)
  INTEGER :: info, i, arglen, failures
  INTEGER :: nodeC, elemC, bndryC, usedTypes
  INTEGER :: typeTags(16), countByType(16)
  INTEGER, ALLOCATABLE :: tags(:)
  REAL(c_double), ALLOCATABLE :: coord(:)
  REAL(c_double) :: expect_x(EXPECT_NODES), expect_y(EXPECT_NODES)
  LOGICAL :: coords_ok

  expect_x = (/ 0.0_c_double, 1.0_c_double, 1.0_c_double, 0.0_c_double /)
  expect_y = (/ 0.0_c_double, 0.0_c_double, 1.0_c_double, 1.0_c_double /)

  failures = 0

  IF (COMMAND_ARGUMENT_COUNT() < 1) THEN
     WRITE(*,*) 'usage: eio_read_fortran <mesh directory>'
     STOP 2
  END IF
  CALL GET_COMMAND_ARGUMENT(1, argdir, arglen)

  ! The C side expects a NUL terminated string, which a Fortran character
  ! variable is not. Building it explicitly rather than relying on trailing
  ! blanks happening to be harmless.
  ALLOCATE(cdir(arglen + 1))
  DO i = 1, arglen
     cdir(i) = argdir(i:i)
  END DO
  cdir(arglen + 1) = C_NULL_CHAR

  info = -1
  CALL eio_init(info)
  CALL report(info, 'eio_init')

  CALL eio_open_model(cdir, info)
  CALL report(info, 'eio_open_model')

  CALL eio_open_mesh(cdir, info)
  CALL report(info, 'eio_open_mesh')

  nodeC = -1; elemC = -1; bndryC = -1; usedTypes = -1
  typeTags = 0; countByType = 0
  CALL eio_get_mesh_description(nodeC, elemC, bndryC, usedTypes, &
       typeTags, countByType, info)
  CALL report(info, 'eio_get_mesh_description')

  CALL expect(nodeC, EXPECT_NODES, 'node count')
  CALL expect(elemC, EXPECT_ELEMENTS, 'element count')
  CALL expect(bndryC, EXPECT_BOUNDARY, 'boundary element count')

  IF (nodeC == EXPECT_NODES) THEN
     ALLOCATE(tags(nodeC), coord(3 * nodeC))
     tags = -1
     coord = -1.0_c_double
     CALL eio_get_mesh_nodes(tags, coord, info)
     CALL report(info, 'eio_get_mesh_nodes')

     ! Interleaved (x, y, z) triples, matching EIOMeshAgent::read_allNodes.
     coords_ok = .TRUE.
     DO i = 1, nodeC
        IF (tags(i) /= i) coords_ok = .FALSE.
        IF (ABS(coord(3*i - 2) - expect_x(i)) > 1.0e-12_c_double) coords_ok = .FALSE.
        IF (ABS(coord(3*i - 1) - expect_y(i)) > 1.0e-12_c_double) coords_ok = .FALSE.
        IF (ABS(coord(3*i    ) - 0.0_c_double) > 1.0e-12_c_double) coords_ok = .FALSE.
     END DO
     IF (coords_ok) THEN
        WRITE(*,*) '  ok   node tags and coordinates read through eiof'
     ELSE
        WRITE(*,*) '  FAIL node tags and coordinates read through eiof'
        failures = failures + 1
        DO i = 1, nodeC
           WRITE(*,*) '       node', tags(i), coord(3*i-2), coord(3*i-1), coord(3*i)
        END DO
     END IF
     DEALLOCATE(tags, coord)
  END IF

  CALL eio_close_mesh(info)
  CALL eio_close_model(info)
  CALL eio_close(info)

  IF (failures == 0) THEN
     WRITE(*,*) 'PASSED with 0 failures'
  ELSE
     WRITE(*,*) 'FAILED with', failures, 'failures'
     STOP 1
  END IF

CONTAINS

  ! Every eio entry point reports through an out parameter, so returning is
  ! not the same as succeeding and the value has to be checked.
  SUBROUTINE report(code, what)
    INTEGER, INTENT(IN) :: code
    CHARACTER(LEN=*), INTENT(IN) :: what
    IF (code == 0) THEN
       WRITE(*,*) '  ok   ', TRIM(what)
    ELSE
       WRITE(*,*) '  FAIL ', TRIM(what), ' info=', code
       failures = failures + 1
    END IF
  END SUBROUTINE report

  SUBROUTINE expect(got, want, what)
    INTEGER, INTENT(IN) :: got, want
    CHARACTER(LEN=*), INTENT(IN) :: what
    IF (got == want) THEN
       WRITE(*,*) '  ok   ', TRIM(what), ' =', got
    ELSE
       WRITE(*,*) '  FAIL ', TRIM(what), ' got', got, ' wanted', want
       failures = failures + 1
    END IF
  END SUBROUTINE expect

END PROGRAM eio_read_fortran
