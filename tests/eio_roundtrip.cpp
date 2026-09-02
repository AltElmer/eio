/* Write an Elmer mesh through eio, read it back through eio, and require that
   what comes back is what went in.

   eio's own TODO has said "write tests" since 2005. This is that test. It is
   deliberately a round trip rather than a smoke test: a call sequence that
   merely returns without complaining proves nothing, because every eio entry
   point reports through an out parameter and returning is not succeeding.

   The mesh is a single square, four nodes, one 404 element, four boundary
   elements. Small enough to state the expected answer in full, which is what
   makes the assertions meaningful.  */

#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <string>
#include <iostream>

#include "eio_api.h"

static int failures = 0;

static void check(bool ok, const std::string& what)
{
  std::cout << (ok ? "  ok   " : "  FAIL ") << what << "\n";
  if (!ok) ++failures;
}

/* Every eio call reports through an int& out parameter. A test that ignores
   it would pass on a library that does nothing at all. */
static void check_info(int info, const std::string& call)
{
  check(info == 0, call + " reported info=" + std::to_string(info));
}

int main(int argc, char** argv)
{
  if (argc < 2) {
    std::cerr << "usage: eio_roundtrip <model directory>\n";
    return 2;
  }
  const char* dir = argv[1];

  const int NODES = 4;
  const int ELEMENTS = 1;
  const int BOUNDARY = 4;

  /* An Elmer 404 is a four node quadrilateral; 202 a two node line. */
  const double x[NODES] = { 0.0, 1.0, 1.0, 0.0 };
  const double y[NODES] = { 0.0, 0.0, 1.0, 1.0 };

  int info = -1;

  /* ---- write ---- */
  eio_init(info);
  check_info(info, "eio_init");

  eio_create_model(const_cast<char*>(dir), info);
  check_info(info, "eio_create_model");

  eio_create_mesh(const_cast<char*>(dir), info);
  check_info(info, "eio_create_mesh");

  int nodeC = NODES, elemC = ELEMENTS, bndryC = BOUNDARY, usedTypes = 2;
  int typeTags[2] = { 404, 202 };
  int countByType[2] = { 1, 4 };
  eio_set_mesh_description(nodeC, elemC, bndryC, usedTypes,
                           typeTags, countByType, info);
  check_info(info, "eio_set_mesh_description");

  for (int i = 0; i < NODES; ++i) {
    int tag = i + 1;
    int constraint = 0;
    double coord[3] = { x[i], y[i], 0.0 };
    eio_set_mesh_node(tag, constraint, coord, info);
    if (info != 0) check_info(info, "eio_set_mesh_node");
  }

  {
    int tag = 1, body = 1, type = 404;
    int nodes[4] = { 1, 2, 3, 4 };
    eio_set_mesh_element_conns(tag, body, type, nodes, info);
    check_info(info, "eio_set_mesh_element_conns");
  }

  for (int i = 0; i < BOUNDARY; ++i) {
    int tag = i + 1;
    int boundary = i + 1;
    int leftElement = 1, rightElement = -1, type = 202;
    int nodes[2] = { i + 1, (i + 1) % NODES + 1 };
    eio_set_mesh_bndry_element(tag, boundary, leftElement, rightElement,
                               type, nodes, info);
    if (info != 0) check_info(info, "eio_set_mesh_bndry_element");
  }

  eio_close_mesh(info);
  check_info(info, "eio_close_mesh");
  eio_close_model(info);
  check_info(info, "eio_close_model");
  eio_close(info);
  check_info(info, "eio_close");

  /* ---- read back ---- */
  eio_init(info);
  check_info(info, "eio_init (read)");
  eio_open_model(const_cast<char*>(dir), info);
  check_info(info, "eio_open_model");
  eio_open_mesh(const_cast<char*>(dir), info);
  check_info(info, "eio_open_mesh");

  int rNodeC = -1, rElemC = -1, rBndryC = -1, rTypes = -1;
  int rTypeTags[16] = { 0 };
  int rCountByType[16] = { 0 };
  eio_get_mesh_description(rNodeC, rElemC, rBndryC, rTypes,
                           rTypeTags, rCountByType, info);
  check_info(info, "eio_get_mesh_description");

  check(rNodeC == NODES,
        "node count " + std::to_string(rNodeC) + " == " + std::to_string(NODES));
  check(rElemC == ELEMENTS,
        "element count " + std::to_string(rElemC) + " == " + std::to_string(ELEMENTS));
  check(rBndryC == BOUNDARY,
        "boundary count " + std::to_string(rBndryC) + " == " + std::to_string(BOUNDARY));

  int* tags = new int[rNodeC > 0 ? rNodeC : 1];
  double* coord = new double[(rNodeC > 0 ? rNodeC : 1) * 3];
  eio_get_mesh_nodes(tags, coord, info);
  check_info(info, "eio_get_mesh_nodes");

  if (rNodeC == NODES) {
    /* Coordinates come back as interleaved (x, y, z) triples: EIOMeshAgent's
       read_allNodes writes coord[pt], coord[pt+1], coord[pt+2] and advances
       pt by three. Asserting the values rather than only the count is the
       point, since a reader that returned the right number of zeroes would
       otherwise pass. */
    bool coords_ok = true;
    for (int i = 0; i < NODES; ++i) {
      if (tags[i] != i + 1) coords_ok = false;
      if (std::fabs(coord[3 * i + 0] - x[i]) > 1e-12) coords_ok = false;
      if (std::fabs(coord[3 * i + 1] - y[i]) > 1e-12) coords_ok = false;
      if (std::fabs(coord[3 * i + 2] - 0.0) > 1e-12) coords_ok = false;
    }
    check(coords_ok, "node tags and coordinates survive the round trip");
    if (!coords_ok) {
      for (int i = 0; i < NODES; ++i)
        std::cout << "       node " << tags[i]
                  << " got (" << coord[3 * i] << ", " << coord[3 * i + 1]
                  << ", " << coord[3 * i + 2] << ")"
                  << " expected (" << x[i] << ", " << y[i] << ", 0)\n";
    }
  }

  delete[] tags;
  delete[] coord;

  eio_close_mesh(info);
  eio_close_model(info);
  eio_close(info);

  std::cout << (failures ? "FAILED" : "PASSED")
            << " with " << failures << " failure(s)\n";
  return failures ? 1 : 0;
}
