/*
 * Copyright (C) 2008 Ole Andr� Vadla Ravn�s <ole.andre.ravnas@tandberg.com>
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

#include <stdlib.h>
#include <gum/gum.h>

#define READ_PROBE_COUNTERS() \
  g_object_get (probe,\
      "malloc-count", &malloc_count,\
      "realloc-count", &realloc_count,\
      "free-count", &free_count,\
      NULL);

static gpointer concurrency_torture_helper (gpointer data);

static void
test_new_delete (void)
{
  GumAllocatorProbe * probe;
  guint malloc_count, realloc_count, free_count;
  int * a;

  probe = gum_allocator_probe_new ();

  g_object_set (probe, "enable-counters", TRUE, NULL);

  READ_PROBE_COUNTERS ();
  g_assert_cmpuint (malloc_count, ==, 0);
  g_assert_cmpuint (realloc_count, ==, 0);
  g_assert_cmpuint (free_count, ==, 0);

  a = new int;
  READ_PROBE_COUNTERS ();
  g_assert_cmpuint (malloc_count, ==, 0);
  g_assert_cmpuint (realloc_count, ==, 0);
  g_assert_cmpuint (free_count, ==, 0);

  delete a;

  gum_allocator_probe_attach (probe);

  a = new int;
  READ_PROBE_COUNTERS ();
  g_assert_cmpuint (malloc_count, ==, 1);
  g_assert_cmpuint (realloc_count, ==, 0);
  g_assert_cmpuint (free_count, ==, 0);

  delete a;
  READ_PROBE_COUNTERS ();
  g_assert_cmpuint (malloc_count, ==, 1);
  g_assert_cmpuint (realloc_count, ==, 0);
  g_assert_cmpuint (free_count, ==, 1);

  gum_allocator_probe_detach (probe);

  READ_PROBE_COUNTERS ();
  g_assert_cmpuint (malloc_count, ==, 0);
  g_assert_cmpuint (realloc_count, ==, 0);
  g_assert_cmpuint (free_count, ==, 0);

  g_object_unref (probe);
}

static void
test_concurrency (void)
{
  GumAllocatorProbe * probe = gum_allocator_probe_new ();
  gum_allocator_probe_attach (probe);

  GThread * thread = g_thread_create (concurrency_torture_helper, NULL, TRUE,
      NULL);

  g_thread_yield ();

  for (int i = 0; i < 2000; i++)
  {
    int * a = new int;
    delete a;
  }

  g_thread_join (thread);

  gum_allocator_probe_detach (probe);
  g_object_unref (probe);
}

static gpointer
concurrency_torture_helper (gpointer data)
{
  for (int i = 0; i < 2000; i++)
  {
    void * b = malloc (1);
    free (b);
  }

  return NULL;
}

G_BEGIN_DECLS

void
gum_test_register_allocator_probe_cxx_tests (void)
{
  g_test_add_func ("/Gum/AllocatorProbe/test-new-delete", &test_new_delete);
  g_test_add_func ("/Gum/AllocatorProbe/test-concurrency", &test_concurrency);
}

G_END_DECLS