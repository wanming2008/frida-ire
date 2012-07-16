#ifndef __CLOUD_SPY_PLUGIN_H__
#define __CLOUD_SPY_PLUGIN_H__

#include <glib.h>
#ifdef G_OS_WIN32
# define VC_EXTRALEAN
# include <windows.h>
# include <tchar.h>
#endif
#include "npfunctions.h"

#define CLOUD_SPY_ATTACHPOINT() \
  MessageBox (NULL, _T (__FUNCTION__), _T (__FUNCTION__), MB_ICONINFORMATION | MB_OK)

G_BEGIN_DECLS

NPError OSCALL NP_GetEntryPoints (NPPluginFuncs * pf);
NPError OSCALL NP_Initialize (NPNetscapeFuncs * nf);
NPError OSCALL NP_Shutdown (void);
const char * NP_GetMIMEDescription (void);

G_GNUC_INTERNAL extern NPNetscapeFuncs * cloud_spy_nsfuncs;
G_GNUC_INTERNAL extern GMainContext * cloud_spy_main_context;

G_GNUC_INTERNAL void cloud_spy_init_npvariant_with_string (NPVariant * var, const gchar * str);

G_END_DECLS

#endif
