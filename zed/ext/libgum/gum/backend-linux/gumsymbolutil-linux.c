/*
 * Copyright (C) 2010 Ole André Vadla Ravnås <ole.andre.ravnas@tandberg.com>
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

#include "gumsymbolutil.h"

#include <stdio.h>
#include <string.h>

#define GUM_MAPS_LINE_SIZE (1024 + PATH_MAX)

void
gum_process_enumerate_modules (GumFoundModuleFunc func,
                               gpointer user_data)
{
  FILE * fp;
  const guint line_size = GUM_MAPS_LINE_SIZE;
  gchar * line, * path, * prev_path;
  gboolean carry_on = TRUE;

  fp = fopen ("/proc/self/maps", "r");
  g_assert (fp != NULL);

  line = g_malloc (line_size);

  path = g_malloc (PATH_MAX);
  prev_path = g_malloc (PATH_MAX);
  prev_path[0] = '\0';

  while (carry_on && fgets (line, line_size, fp) != NULL)
  {
    const guint8 elf_magic[] = { 0x7f, 'E', 'L', 'F' };
    guint8 * start;
    gint n;
    gchar * name;

    n = sscanf (line, "%p-%*p %*s %*x %*s %*s %s", &start, path);
    if (n == 1)
      continue;
    g_assert_cmpint (n, ==, 2);

    if (strcmp (path, prev_path) == 0 || path[0] == '[')
      continue;
    else if (memcmp (start, elf_magic, sizeof (elf_magic)) != 0)
      continue;

    name = g_path_get_basename (path);
    carry_on = func (name, start, path, user_data);
    g_free (name);

    strcpy (prev_path, path);
  }

  g_free (path);
  g_free (prev_path);

  g_free (line);

  fclose (fp);
}

void
gum_process_enumerate_ranges (GumPageProtection prot,
                              GumFoundRangeFunc func,
                              gpointer user_data)
{
  FILE * fp;
  const guint line_size = GUM_MAPS_LINE_SIZE;
  gchar * line;
  gboolean carry_on = TRUE;

  fp = fopen ("/proc/self/maps", "r");
  g_assert (fp != NULL);

  line = g_malloc (line_size);

  while (carry_on && fgets (line, line_size, fp) != NULL)
  {
    guint8 * start, * end;
    gchar perms[4 + 1] = { 0, };
    gint n;
    GumPageProtection cur_prot = GUM_PAGE_NO_ACCESS;

    n = sscanf (line, "%p-%p %4s", &start, &end, perms);
    g_assert_cmpint (n, ==, 3);

    if (perms[0] == 'r')
      cur_prot |= GUM_PAGE_READ;
    if (perms[1] == 'w')
      cur_prot |= GUM_PAGE_WRITE;
    if (perms[2] == 'x')
      cur_prot |= GUM_PAGE_EXECUTE;

    if ((cur_prot & prot) == prot)
    {
      GumMemoryRange range;

      range.base_address = start;
      range.size = end - start;

      carry_on = func (&range, cur_prot, user_data);
    }
  }

  g_free (line);

  fclose (fp);
}

void
gum_module_enumerate_exports (const gchar * module_name,
                              GumFoundExportFunc func,
                              gpointer user_data)
{
}

void
gum_module_enumerate_ranges (const gchar * module_name,
                             GumPageProtection prot,
                             GumFoundRangeFunc func,
                             gpointer user_data)
{
}

gpointer
gum_module_find_export_by_name (const gchar * module_name,
                                const gchar * export_name)
{
  return NULL;
}
