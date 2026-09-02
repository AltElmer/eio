CMAKE_MINIMUM_REQUIRED(VERSION 3.12)

# EIO builds two ways: on its own, and as a subdirectory of a larger project
# such as Elmer. Everything a top level project has to supply lives in the
# standalone block below, so that adding this directory with ADD_SUBDIRECTORY
# changes nothing about the parent's configuration.
IF(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  SET(EIO_STANDALONE TRUE)
ELSE()
  SET(EIO_STANDALONE FALSE)
ENDIF()

IF(EIO_STANDALONE)
  # 5.4.0 is the version eio carried in Elmer's release notes, the last time it
  # was released under a version number of its own.
  PROJECT(EIO VERSION 5.4.0 LANGUAGES CXX)

  SET(CMAKE_CXX_STANDARD 11)
  SET(CMAKE_CXX_STANDARD_REQUIRED ON)

  IF(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    SET(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
  ENDIF()

  # Consistent across compilers rather than tuned for any one of them.
  SET(CMAKE_POSITION_INDEPENDENT_CODE ON)

  IF(MSVC)
    # The sources predate the C++ standard library's own headers being
    # scrupulous about deprecated C calls, and use sprintf and strcpy
    # throughout. Warnings, not errors.
    ADD_COMPILE_DEFINITIONS(_CRT_SECURE_NO_WARNINGS)
  ENDIF()

  INCLUDE(CTest)
ENDIF()

OPTION(EIO_WITH_FORTRAN "Build eiof, the Fortran binding library" ON)
OPTION(EIO_BUILD_TESTS "Build the eio tests" ${EIO_STANDALONE})

# The Fortran binding is genuinely optional: eioc is a complete C++ library on
# its own, and MSVC ships no Fortran compiler. Rather than failing on a
# toolchain that cannot possibly satisfy the requirement, detect and report.
SET(EIO_FORTRAN FALSE)
IF(EIO_WITH_FORTRAN)
  INCLUDE(CheckLanguage)
  CHECK_LANGUAGE(Fortran)
  IF(CMAKE_Fortran_COMPILER)
    IF(EIO_STANDALONE)
      ENABLE_LANGUAGE(Fortran)
    ENDIF()
    SET(EIO_FORTRAN TRUE)
  ELSE()
    MESSAGE(STATUS "eio: no Fortran compiler found, building eioc only")
  ENDIF()
ENDIF()

INCLUDE(CheckIncludeFiles)
CHECK_INCLUDE_FILES(inttypes.h HAVE_INTTYPES_H)

# USE_ISO_C_BINDINGS is not optional despite the #ifdef in the template: the
# Fortran side binds to explicitly named lowercase C symbols, so FC_FUNC has to
# be the identity mapping. It is set here rather than left to the caller
# because getting it wrong produces link errors rather than a clear diagnostic.
SET(USE_ISO_C_BINDINGS TRUE)

CONFIGURE_FILE(eio_build_config.h.cmake
               "${CMAKE_CURRENT_BINARY_DIR}/eio_build_config.h")

ADD_SUBDIRECTORY(src)

IF(EIO_BUILD_TESTS)
  ENABLE_TESTING()
  ADD_SUBDIRECTORY(tests)
ENDIF()

IF(EIO_STANDALONE)
  IF(EIO_FORTRAN)
    MESSAGE(STATUS "eio ${PROJECT_VERSION}: building eioc and eiof")
  ELSE()
    MESSAGE(STATUS "eio ${PROJECT_VERSION}: building eioc")
  ENDIF()
ENDIF()
