SERVER := $(top_builddir)/src/zed-server

lib_LTLIBRARIES = libcloud-spy-data.la libcloud-spy-codegen.la libcloud-spy.la

libcloud_spy_codegen_la_SOURCES = \
	cloud-spy-api.vala \
	cloud-spy-root.vala
libcloud_spy_codegen_la_CFLAGS = \
	-w
libcloud_spy_codegen_la_LDFLAGS = \
	-export-symbols-regex "^__hack_to_force_build_order__$$"
libcloud_spy_codegen_la_VALAFLAGS = \
	--library=cloud-spy \
	--header=cloud-spy.h \
	--vapidir=$(top_srcdir)/vapi \
	--vapidir=$(top_builddir)/src \
	--vapidir=$(top_builddir)/lib/interfaces \
	--vapidir=$(sourcedir) \
	--pkg=cloud-spy-object \
	--pkg=cloud-spy-data \
	--pkg=config \
	--pkg=gee-1.0 \
	--pkg=gio-2.0 \
	--pkg=zed-core \
	--pkg=zed-interfaces

libcloud_spy_la_SOURCES = \
	cloud-spy-plugin.h \
	cloud-spy-plugin.cpp \
	cloud-spy-object.h \
	cloud-spy-object.cpp \
	cloud-spy-variant.h \
	cloud-spy-variant.cpp \
	cloud-spy-api-glue.c \
	cloud-spy-root.c
libcloud_spy_la_CFLAGS = \
	-w
libcloud_spy_la_LDFLAGS = \
	-export-symbols-regex "^(NP_GetEntryPoints|NP_Initialize|NP_Shutdown|NP_GetMIMEDescription)$$" \
	$(ZED_LDFLAGS)
libcloud_spy_la_LIBADD = \
	$(top_builddir)/src/libzed-core.la \
	$(builddir)/libcloud-spy-data.la \
	$(ZED_LIBS)
libcloud_spy_la_LIBTOOLFLAGS = \
	--tag=disable-static

CLEANFILES = \
	$(builddir)/cloud-spy-data.c
libcloud_spy_data_la_SOURCES = \
	$(builddir)/cloud-spy-data.c
libcloud_spy_data_la_LDFLAGS = \
	-export-symbols-regex "^__hack_to_force_build_order__$$"
libcloud_spy_data_la_LIBTOOLFLAGS = \
	--tag=disable-shared
cloud-spy-data.c: $(SERVER)
	$(AM_V_GEN) \
		"$(top_builddir)/tools/resource-compiler" \
			-c "$(srcdir)/cloud-spy.resources" \
			-o "$(builddir)/cloud-spy-data" \
			$(SERVER)

AM_CPPFLAGS = \
	-include config.h \
	-I $(top_builddir)/src \
	-I $(top_builddir)/lib/interfaces \
	$(ZED_CFLAGS)