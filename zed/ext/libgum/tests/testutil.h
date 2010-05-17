/*
 * Copyright (C) 2008 Ole Andr� Vadla Ravn�s <ole.andre.ravnas@tandberg.com>
 * Copyright (C) 2008 Christian Berentsen <christian.berentsen@tandberg.com>
 * Copyright (C) 2009 Haakon Sporsheim <haakon.sporsheim@tandberg.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __TEST_UTIL_H__
#define __TEST_UTIL_H__

#include <gum/gum.h>
#include <gum/gum-heap.h>
#include <gum/gum-prof.h>

#define TEST_LIST_BEGIN(NAME)       void test_ ##NAME## _add_tests (void) {
#define TEST_LIST_END()             }

#define TEST_ENTRY_SIMPLE(NAME, FUNC)                                     \
  G_STMT_START                                                            \
  {                                                                       \
    static void FUNC (void);                                              \
    g_test_add_func ("/" #NAME "/" #FUNC, FUNC);                          \
  }                                                                       \
  G_STMT_END;
#define TEST_ENTRY_WITH_FIXTURE(NAME, PREFIX, FUNC, STRUCT)               \
  G_STMT_START                                                            \
  {                                                                       \
    static void PREFIX## _ ##FUNC (STRUCT * fixture, gconstpointer data); \
    g_test_add ("/" #NAME "/" #FUNC,                                      \
        STRUCT,                                                           \
        NULL,                                                             \
        PREFIX## _fixture_setup,                                          \
        PREFIX## _ ##FUNC,                                                \
        PREFIX## _fixture_teardown);                                      \
  }                                                                       \
  G_STMT_END;

#define TEST_RUN_LIST(NAME)                                               \
  G_STMT_START                                                            \
  {                                                                       \
    extern void test_ ##NAME## _add_tests (void);                         \
    test_ ##NAME## _add_tests ();                                         \
  }                                                                       \
  G_STMT_END

G_BEGIN_DECLS

GumSampler * heap_access_counter_new (void);

void assert_basename_equals (const gchar * expected_filename,
    const gchar * actual_filename);

gchar * test_util_diff_xml (const gchar * expected_xml,
    const gchar * actual_xml);

G_END_DECLS

#endif