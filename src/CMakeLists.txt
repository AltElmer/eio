# The agents are the library: one per section of an Elmer model directory.
# Shared by both bindings, so compiled once into an object library rather than
# twice as the original build did.
SET(EIO_AGENT_SRCS
  EIOConstraintAgent.cpp
  EIODualMeshAgent.cpp
  EIOGeometryAgent.cpp
  EIOMeshAgent.cpp
  EIOModelDataAgent.cpp
  EIOModelManager.cpp
  EIOPartWriter.cpp
  EIOSolverAgent.cpp)

# Deliberately not built, and not an oversight:
#
#   EIOPartReader.cpp  references an identifier "meshdir" that is not a member
#                      of its class and is not declared anywhere in the tree.
#                      It has never appeared in any of eio's build files, in
#                      autotools or CMake, since the code entered version
#                      control in April 2005. It has therefore never compiled.
#   eio_api.cpp        the single-binding API that eio_api_c.cpp and
#                      eio_api_f.cpp replaced. Superseded, and it no longer
#                      compiles either.
#
# Both are kept in the tree because they are the record of how the partitioned
# reader and the old API were meant to work, and because deleting a component's
# only description of a missing feature is not a decision this repository
# should take on upstream's behalf. See the README.

ADD_LIBRARY(eio_agents OBJECT ${EIO_AGENT_SRCS})
TARGET_INCLUDE_DIRECTORIES(eio_agents PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>"
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/..>")

# The C++ binding. "eioc" is the name Elmer linked against, kept so that this
# repository can be dropped in as a subdirectory without touching the parent.
ADD_LIBRARY(eioc eio_api_c.cpp $<TARGET_OBJECTS:eio_agents>)
TARGET_INCLUDE_DIRECTORIES(eioc PUBLIC
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>"
  "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/..>")

IF(EIO_FORTRAN)
  ADD_LIBRARY(eiof eio_api_f.cpp eio_api_f.f90 $<TARGET_OBJECTS:eio_agents>)
  TARGET_INCLUDE_DIRECTORIES(eiof PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/../include>"
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/..>")
  SET_TARGET_PROPERTIES(eiof PROPERTIES
    Fortran_MODULE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/modules")
  # Anything that USEs EIOFortranAPI needs the .mod on its include path, so
  # the module directory travels with the target rather than having to be
  # spelled out again by every consumer.
  TARGET_INCLUDE_DIRECTORIES(eiof PUBLIC
    "$<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/modules>")
ENDIF()
