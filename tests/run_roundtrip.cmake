# Runs the round trip in a directory created fresh for the purpose, then checks
# that the four mesh files exist and are not empty.
#
# The executable's own assertions are the substance of the test; this wrapper
# exists so that a stale model directory from an earlier run cannot let the
# reading half pass while the writing half is broken.

IF(EXISTS "${EIO_WORKDIR}")
  FILE(REMOVE_RECURSE "${EIO_WORKDIR}")
ENDIF()
FILE(MAKE_DIRECTORY "${EIO_WORKDIR}")

EXECUTE_PROCESS(COMMAND "${EIO_EXE}" "${EIO_WORKDIR}"
                RESULT_VARIABLE rc
                OUTPUT_VARIABLE out
                ERROR_VARIABLE err)
MESSAGE("${out}")
IF(err)
  MESSAGE("stderr: ${err}")
ENDIF()

IF(NOT rc EQUAL 0)
  MESSAGE(FATAL_ERROR "eio_roundtrip exited ${rc}")
ENDIF()

FOREACH(f mesh.header mesh.nodes mesh.elements mesh.boundary)
  IF(NOT EXISTS "${EIO_WORKDIR}/${f}")
    MESSAGE(FATAL_ERROR "eio wrote no ${f}")
  ENDIF()
  FILE(SIZE "${EIO_WORKDIR}/${f}" sz)
  IF(sz EQUAL 0)
    MESSAGE(FATAL_ERROR "${f} is empty")
  ENDIF()
  MESSAGE("  ok    ${f} written, ${sz} bytes")
ENDFOREACH()

# Nothing is printed here on success on purpose. The test's PASS_REGULAR_EXPRESSION
# has to be satisfied by the executable's own summary line, so that a wrapper
# that ran while the assertions did not cannot make the test pass.
