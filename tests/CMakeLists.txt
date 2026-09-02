ADD_EXECUTABLE(eio_roundtrip eio_roundtrip.cpp)
TARGET_LINK_LIBRARIES(eio_roundtrip PRIVATE eioc)

# Each run gets its own directory, and it is created fresh, because eio writes
# a model as a directory of files and a stale one from a previous run could let
# the read half pass while the write half is broken.
ADD_TEST(NAME eio_roundtrip
         COMMAND ${CMAKE_COMMAND}
                 -DEIO_EXE=$<TARGET_FILE:eio_roundtrip>
                 -DEIO_WORKDIR=${CMAKE_CURRENT_BINARY_DIR}/roundtrip-model
                 -P ${CMAKE_CURRENT_SOURCE_DIR}/run_roundtrip.cmake)

# A test that only asserts the exit code of the good path cannot distinguish a
# working library from one whose assertions never run, so require the wording
# the test prints on success.
SET_TESTS_PROPERTIES(eio_roundtrip PROPERTIES
  PASS_REGULAR_EXPRESSION "PASSED with 0 failure"
  FAIL_REGULAR_EXPRESSION "FAIL |FAILED")

# eiof is the library Elmer's solver linked against, so building it without
# running it would leave the more important of the two untested.
IF(EIO_FORTRAN)
  ADD_EXECUTABLE(eio_read_fortran eio_read_fortran.f90)
  TARGET_LINK_LIBRARIES(eio_read_fortran PRIVATE eiof)
  # eiof is C++ underneath. A Fortran-driven link does not pull in the C++
  # runtime on its own.
  SET_TARGET_PROPERTIES(eio_read_fortran PROPERTIES LINKER_LANGUAGE Fortran)
  TARGET_LINK_LIBRARIES(eio_read_fortran PRIVATE ${CMAKE_CXX_IMPLICIT_LINK_LIBRARIES})

  # Reads a mesh checked into the repository, not one written moments earlier
  # by the C++ test: a reader that agrees only with its own writer would pass
  # a round trip while being wrong about Elmer's actual format.
  ADD_TEST(NAME eio_read_fortran
           COMMAND eio_read_fortran "${CMAKE_CURRENT_SOURCE_DIR}/square")
  SET_TESTS_PROPERTIES(eio_read_fortran PROPERTIES
    PASS_REGULAR_EXPRESSION "PASSED with 0 failures"
    FAIL_REGULAR_EXPRESSION "FAIL |FAILED")
ENDIF()
