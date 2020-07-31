##============================================================================
##
##   SSSS    tt          lll  lll
##  SS  SS   tt           ll   ll
##  SS     tttttt  eeee   ll   ll   aaaa
##   SSSS    tt   ee  ee  ll   ll      aa
##      SS   tt   eeeeee  ll   ll   aaaaa  --  "An Atari 2600 VCS Emulator"
##  SS  SS   tt   ee      ll   ll  aa  aa
##   SSSS     ttt  eeeee llll llll  aaaaa
##
## Copyright (c) 1995-2020 by Bradford W. Mott, Stephen Anthony
## and the Stella Team
##
## See the file "License.txt" for information on usage and redistribution of
## this file, and for a DISCLAIMER OF ALL WARRANTIES.
##============================================================================

#######################################################################
# Default compilation parameters. Normally don't edit these           #
#######################################################################

srcdir      ?= .

DEFINES     := -DSDL_SUPPORT -D_GLIBCXX_USE_CXX11_ABI=1
LDFLAGS     := -pthread
INCLUDES    :=
LIBS	    :=
OBJS	    :=
PROF        :=

MODULES     :=
MODULE_DIRS :=

DISTNAME    := stella-snapshot

# Load the make rules generated by configure
include config.mak

# Uncomment this for stricter compile time code verification
# CXXFLAGS+= -Werror

ifdef CXXFLAGS
  CXXFLAGS:= $(CXXFLAGS) -x c++
else
  CXXFLAGS:= -O2 -x c++
endif

CXXFLAGS+= -Wall -Wextra -Wno-unused-parameter

ifdef HAVE_GCC
  CXXFLAGS+= -Wno-multichar -Wunused -fno-rtti -Woverloaded-virtual -Wnon-virtual-dtor -std=c++14
endif

ifdef HAVE_CLANG
  CXXFLAGS+= -Wno-multichar -Wunused -fno-rtti -Woverloaded-virtual -Wnon-virtual-dtor -std=c++14
endif

ifdef CLANG_WARNINGS
  CXXFLAGS+= -Weverything -Wno-c++17-extensions  -Wno-c++98-compat-pedantic \
    -Wno-switch-enum -Wno-conversion -Wno-covered-switch-default \
    -Wno-inconsistent-missing-destructor-override -Wno-float-equal \
    -Wno-exit-time-destructors -Wno-global-constructors -Wno-weak-vtables \
    -Wno-four-char-constants -Wno-padded
endif

ifdef PROFILE
  PROF:= -pg -fprofile-arcs -ftest-coverage
  CXXFLAGS+= $(PROF)
endif

ifdef DEBUG
  CXXFLAGS += -g
else
  ifdef HAVE_GCC
    CXXFLAGS+= -fomit-frame-pointer
  endif

  ifdef HAVE_CLANG
    CXXFLAGS+= -fomit-frame-pointer
  endif
endif

#######################################################################
# Misc stuff - you should never have to edit this                     #
#######################################################################

ifdef STELLA_BUILD_ROOT
  OBJECT_ROOT := $(STELLA_BUILD_ROOT)/stella-out
else
  OBJECT_ROOT := out
endif
OBJECT_ROOT_PROFILE_GENERERATE := out.pgen
OBJECT_ROOT_PROFILE_USE := out.pgo

EXECUTABLE := stella$(EXEEXT)
EXECUTABLE_PROFILE_GENERATE := stella-pgo-generate$(EXEEXT)
EXECUTABLE_PROFILE_USE := stella-pgo$(EXEEXT)

PROFILE_DIR = $(CURDIR)/test/roms/profile
PROFILE_OUT = $(PROFILE_DIR)/out
PROFILE_STAMP = profile.stamp

CXXFLAGS_PROFILE_GENERATE = $(CXXFLAGS)
CXXFLAGS_PROFILE_USE = $(CXXFLAGS)
LDFLAGS_PROFILE_GENERATE = $(LDFLAGS)
STELLA_PROFILE_GENERATE = $(BINARY_LOADER) ./$(EXECUTABLE_PROFILE_GENERATE) -profile \
	$(PROFILE_DIR)/128.bin:10 \
	$(PROFILE_DIR)/catharsis_theory.bin:60

ifdef HAVE_CLANG
	CXXFLAGS_PROFILE_GENERATE += -fprofile-generate=$(PROFILE_OUT)
	CXXFLAGS_PROFILE_USE += -fprofile-use=$(PROFILE_OUT)
	LDFLAGS_PROFILE_GENERATE += -fprofile-generate
	STELLA_PROFILE_GENERATE := \
		LLVM_PROFILE_FILE="$(PROFILE_OUT)/default.profraw" $(STELLA_PROFILE_GENERATE) && \
		$(LLVM_PROFDATA) merge -o $(PROFILE_OUT)/default.profdata $(PROFILE_OUT)/default.profraw
endif

ifdef HAVE_GCC
	CXXFLAGS_PROFILE_GENERATE += -fprofile-generate -fprofile-dir=$(PROFILE_OUT)
	CXXFLAGS_PROFILE_USE += -fprofile-use -fprofile-dir=$(PROFILE_OUT)
	LDFLAGS_PROFILE_GENERATE += -fprofile-generate
	STELLA_PROFILE_GENERATE := $(STELLA_PROFILE_GENERATE) && \
	  rm -fr $(PROFILE_OUT)/$(OBJECT_ROOT_PROFILE_USE) && \
		mv $(PROFILE_OUT)/$(OBJECT_ROOT_PROFILE_GENERERATE) $(PROFILE_OUT)/$(OBJECT_ROOT_PROFILE_USE)
endif

all: $(EXECUTABLE)

pgo: $(EXECUTABLE_PROFILE_USE)

######################################################################
# Various minor settings
######################################################################

# The name for the directory used for dependency tracking
DEPDIR := .deps


######################################################################
# Module settings
######################################################################

MODULES := $(MODULES)

# After the game specific modules follow the shared modules
MODULES += \
	src/common \
	src/common/audio \
	src/common/tv_filters \
	src/emucore \
	src/emucore/tia \
	src/emucore/tia/frame-manager

######################################################################
# The build rules follow - normally you should have no need to
# touch whatever comes after here.
######################################################################

# Concat DEFINES and INCLUDES to form the CPPFLAGS
CPPFLAGS:= $(DEFINES) $(INCLUDES)

# Include the build instructions for all modules
-include $(addprefix $(srcdir)/, $(addsuffix /module.mk,$(MODULES)))

# Depdir information
DEPDIRS = $(addsuffix /$(DEPDIR),$(MODULE_DIRS))
DEPFILES =

OBJ=$(addprefix $(OBJECT_ROOT)/,$(OBJS))
OBJ_PROFILE_GENERATE=$(addprefix $(OBJECT_ROOT_PROFILE_GENERERATE)/,$(OBJS))
OBJ_PROFILE_USE=$(addprefix $(OBJECT_ROOT_PROFILE_USE)/,$(OBJS))

# The build rule for the Stella executable
$(EXECUTABLE): $(OBJ)
	$(LD) $(LDFLAGS) $(PRE_OBJS_FLAGS) $+ $(POST_OBJS_FLAGS) $(LIBS) $(PROF) -o $@

$(EXECUTABLE_PROFILE_GENERATE): $(OBJ_PROFILE_GENERATE)
	$(LD) $(LDFLAGS_PROFILE_GENERATE) $(PRE_OBJS_FLAGS) $+ $(POST_OBJS_FLAGS) $(LIBS) $(PROF) -o $@

$(EXECUTABLE_PROFILE_USE): $(OBJ_PROFILE_USE)
	$(LD) $(LDFLAGS) $(PRE_OBJS_FLAGS) $+ $(POST_OBJS_FLAGS) $(LIBS) $(PROF) -o $@

distclean: clean
	$(RM_REC) $(DEPDIRS)
	$(RM) build.rules config.h config.mak config.log

clean:
	-$(RM) -fr \
		$(OBJECT_ROOT) $(OBJECT_ROOT_PROFILE_GENERERATE) $(OBJECT_ROOT_PROFILE_USE) \
		$(EXECUTABLE) $(EXECUTABLE_PROFILE_GENERATE) $(EXECUTABLE_PROFILE_USE) \
		$(PROFILE_OUT) $(PROFILE_STAMP)

.PHONY: all clean dist distclean

.SUFFIXES: .cxx

define create_dir
$(MKDIR) -p $(*D)/$(DEPDIR)
$(MKDIR) -p $(@D)
endef

define merge_dep
$(ECHO) "$(*D)/" > $(*D)/$(DEPDIR)/$(*F).d
$(CAT) "$(*D)/$(DEPDIR)/$(*F).d2" >> "$(*D)/$(DEPDIR)/$(*F).d"
$(RM) "$(*D)/$(DEPDIR)/$(*F).d2"
endef

ifndef CXX_UPDATE_DEP_FLAG
# If you use GCC, disable the above and enable this for intelligent
# dependency tracking.
CXX_UPDATE_DEP_FLAG = -Wp,-MMD,"$(*D)/$(DEPDIR)/$(*F).d2"

$(OBJECT_ROOT)/%.o: %.cxx
	$(create_dir)
	$(CXX) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS) $(CPPFLAGS) -c $(<) -o $@
	$(merge_dep)

$(OBJECT_ROOT)/%.o: %.c
	$(create_dir)
	$(CC) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS) $(CPPFLAGS) -c $(<) -o $@
	$(merge_dep)

$(OBJECT_ROOT_PROFILE_GENERERATE)/%.pgen.o: %.cxx
	$(create_dir)
	$(CXX) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_GENERATE) $(CPPFLAGS) -c $(<) -o $@
	$(merge_dep)

$(OBJECT_ROOT_PROFILE_GENERERATE)/%.pgen.o: %.cxx
	$(create_dir)
	$(CC) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_GENERATE) $(CPPFLAGS) -c $(<) -o $@
	$(merge_dep)

$(OBJECT_ROOT_PROFILE_USE)/%.pgo.o: %.cxx $(PROFILE_STAMP)
	$(create_dir)
	$(CXX) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_USE) $(CPPFLAGS) -c $(<) -o $@
	$(merge_dep)

$(OBJECT_ROOT_PROFILE_USE)/%.pgo.o: %.cxx $(PROFILE_STAMP)
	$(create_dir)
	$(CC) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_USE) $(CPPFLAGS) -c $(<) -o $@
	$(merge_dep)

else
# If you even have GCC 3.x, you can use this build rule, which is safer; the above
# rule can get you into a bad state if you Ctrl-C at the wrong moment.
# Also, with this GCC inserts additional dummy rules for the involved headers,
# which ensures a smooth compilation even if said headers become obsolete.
$(OBJECT_ROOT)/%.o: %.cxx
	$(create_dir)
	$(CXX) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS) $(CPPFLAGS) -c $(<) -o $@

$(OBJECT_ROOT)/%.o: %.c
	$(create_dir)
	$(CC) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS) $(CPPFLAGS) -c $(<) -o $@

$(OBJECT_ROOT_PROFILE_GENERERATE)/%.o: %.cxx
	$(create_dir)
	$(CXX) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_GENERATE) $(CPPFLAGS) -c $(<) -o $@

$(OBJECT_ROOT_PROFILE_GENERERATE)/%.o: %.c
	$(create_dir)
	$(CC) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_GENERATE) $(CPPFLAGS) -c $(<) -o $@

$(OBJECT_ROOT_PROFILE_USE)/%.o: %.cxx $(PROFILE_STAMP)
	$(create_dir)
	$(CXX) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_USE) $(CPPFLAGS) -c $(<) -o $@

$(OBJECT_ROOT_PROFILE_USE)/%.o: %.c $(PROFILE_STAMP)
	$(create_dir)
	$(CC) $(CXX_UPDATE_DEP_FLAG) $(CXXFLAGS_PROFILE_USE) $(CPPFLAGS) -c $(<) -o $@

endif

# Include the dependency tracking files. We add /dev/null at the end
# of the list to avoid a warning/error if no .d file exist
-include $(wildcard $(addsuffix /*.d,$(DEPDIRS))) /dev/null

$(PROFILE_STAMP): $(EXECUTABLE_PROFILE_GENERATE)
	-rm -fr $(PROFILE_OUT)
	$(STELLA_PROFILE_GENERATE)
	touch $(PROFILE_STAMP)

# check if configure has been run or has been changed since last run
config.mak: $(srcdir)/configure
	@echo "You need to run ./configure before you can run make"
	@echo "Either you haven't run it before or it has changed."
	@exit 1

install: all
	$(INSTALL) -d "$(DESTDIR)$(BINDIR)"
	$(INSTALL) -c -m 755 "$(srcdir)/stella$(EXEEXT)" "$(DESTDIR)$(BINDIR)/stella$(EXEEXT)"
	$(INSTALL) -d "$(DESTDIR)$(DOCDIR)"
	$(INSTALL) -c -m 644 "$(srcdir)/Announce.txt" "$(srcdir)/Changes.txt" "$(srcdir)/Copyright.txt" "$(srcdir)/License.txt" "$(srcdir)/README-SDL.txt" "$(srcdir)/Readme.txt" "$(srcdir)/Todo.txt" "$(srcdir)/docs/index.html" "$(srcdir)/docs/debugger.html" "$(DESTDIR)$(DOCDIR)/"
	$(INSTALL) -d "$(DESTDIR)$(DOCDIR)/graphics"
	$(INSTALL) -c -m 644 $(wildcard $(srcdir)/docs/graphics/*.png) "$(DESTDIR)$(DOCDIR)/graphics"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/applications"
	$(INSTALL) -c -m 644 "$(srcdir)/src/unix/stella.desktop" "$(DESTDIR)$(DATADIR)/applications"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/16x16/apps"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/22x22/apps"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/24x24/apps"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/32x32/apps"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/48x48/apps"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/64x64/apps"
	$(INSTALL) -d "$(DESTDIR)$(DATADIR)/icons/hicolor/128x128/apps"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-16x16.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/16x16/apps/stella.png"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-22x22.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/22x22/apps/stella.png"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-24x24.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/24x24/apps/stella.png"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-32x32.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/32x32/apps/stella.png"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-48x48.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/48x48/apps/stella.png"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-64x64.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/64x64/apps/stella.png"
	$(INSTALL) -c -m 644 "$(srcdir)/src/common/stella-128x128.png" "$(DESTDIR)$(DATADIR)/icons/hicolor/128x128/apps/stella.png"

install-strip: install
	$(STRIP) stella$(EXEEXT)

uninstall:
	rm -f  "$(DESTDIR)$(BINDIR)/stella$(EXEEXT)"
	rm -rf "$(DESTDIR)$(DOCDIR)/"
	rm -f  "$(DESTDIR)$(DATADIR)/applications/stella.desktop"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/16x16/apps/stella.png"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/22x22/apps/stella.png"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/24x24/apps/stella.png"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/32x32/apps/stella.png"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/48x48/apps/stella.png"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/64x64/apps/stella.png"
	rm -f  "$(DESTDIR)$(DATADIR)/icons/hicolor/128x128/apps/stella.png"

# Special rule for M6502.ins, generated from m4 (there's probably a better way to do this ...)
src/emucore/M6502.ins: src/emucore/M6502.m4
	m4 src/emucore/M6502.m4 > src/emucore/M6502.ins

# Special rule for windows icon stuff (there's probably a better way to do this ...)
src/windows/stella_icon.o: src/windows/stella.ico src/windows/stella.rc
	windres --include-dir src/windows src/windows/stella.rc src/windows/stella_icon.o

.PHONY: deb bundle test install uninstall
