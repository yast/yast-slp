#
# Makefile.am for .../agent-slp/src
#

AM_CXXFLAGS = -DY2LOG=\"agent-slp\" -Wall

plugin_LTLIBRARIES = libpy2ag_slp.la
noinst_LTLIBRARIES = liby2ag_slp.la

liby2ag_slp_la_SOURCES =				\
	SlpAgent.cc					\
	SlpAgent.h
liby2ag_slp_la_LDFLAGS = -version-info 2:0

libpy2ag_slp_la_SOURCES =				\
        $(liby2ag_slp_la_SOURCES)			\
        Y2CCSlpAgent.cc         Y2CCSlpAgent.h
libpy2ag_slp_la_LDFLAGS = -version-info 2:0
libpy2ag_slp_la_LIBADD = -lslp

INCLUDES = -I$(includedir)
