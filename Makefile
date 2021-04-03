################################################################################
#                                                                              #
# GNU Arm Embedded Toolchain project Makefile                                  #
#                                                                              #
################################################################################

PROJECT := gdb-for-firmware
BUILDDIR := build
SOURCES := main.c uart.c startup_stm32f091rctx.s system_stm32f0xx.c
INCLUDES := CMSIS/Device/ST/STM32F0xx/Include CMSIS/Include
DEFINES := STM32F091xC

LINKER_SCRIPT := STM32F091RCTX_FLASH.ld
STDLIB_VARIANT := nano

CPU_FLAGS := -mcpu=cortex-m0 -mthumb -mfloat-abi=soft
OPT_FLAGS := -Og -ffunction-sections -fdata-sections -fno-exceptions -fno-rtti \
    -fno-lto -fno-common -fno-fast-math -Wl,--gc-sections
#OPT_FLAGS += -fno-short-enums
DBG_FLAGS := -ggdb3 -fstack-usage

CFLAGS := -std=gnu11
CXXFLAGS := -std=gnu++11
ASFLAGS :=
CPPFLAGS :=
LDFLAGS :=
LDLIBS :=

DIAGFLAGS := -Wall -Wbad-function-cast -Wcast-align -Wcast-qual -Wconversion
DIAGFLAGS += -Wextra -Wfloat-conversion -Wfloat-equal -Wformat=2
DIAGFLAGS += -Wformat-overflow=2 -Wformat-truncation=2 -Wformat-overflow
DIAGFLAGS += -Wjump-misses-init -Wlogical-op -Wmissing-declarations
DIAGFLAGS += -Wmissing-include-dirs -Wmissing-prototypes -Wpointer-arith
DIAGFLAGS += -Wredundant-decls -Wsequence-point -Wshadow -Wsign-conversion
DIAGFLAGS += -Wstrict-prototypes
#DIAGFLAGS += -Wsuggest-attribute=const
DIAGFLAGS += -Wsuggest-attribute=format -Wtrampolines -Wundef -Wuseless-cast
#DIAGFLAGS += -Wsuggest-attribute=noreturn
#DIAGFLAGS += -Wsuggest-attribute=pure
DIAGFLAGS += -Wvla -Wzero-as-null-pointer-constant -Wno-main
DIAGFLAGS += -Wno-unused-variable -Wno-unused-parameter

################################################################################
#                                                                              #
# Makefile build logic starts here.                                            #
# Ordinarily, there should be no need to edit anything below.                  #
#                                                                              #
################################################################################

################################################################################
#                                                                              #
# SECTION: Auxiliary variables, constants and targets.                         #
#                                                                              #
################################################################################

# Default goal.

.DEFAULT_GOAL: all

.PHONY: all
all: $(TARGET_ELF) | size

# True/false values for use in conditions.

true := T
false :=

# New line char.

define newline :=


endef

# 'Empty' char.

empty :=

# Space char.

space := $(empty) $(empty)

# Define 'space' named variable (really!), that is '$ '. Normally, when long
# lines are being split with '\', Make joins the lines with a single space
# character. Sometimes, this single space is not desired and removing it is
# accomplished by splitting a long line with '$\'. '$' plus single space forms
# a variable named '$ ' and when it's expanded, it expands to a value defined
# below, namely empty value. Thusly, the space between split lines is removed.

$(space) :=

# Single quote character.

squote := '

################################################################################
#                                                                              #
# SECTION: General use helper functions.                                       #
#                                                                              #
################################################################################

# Negates boolean value.
#
# Param: 1: A boolean value.
# Returns: The opposite of the arg. (true -> false, false -> true).

not = $(if $(1),$(false),$(true))

# Compares two strings for equality.
#
# Param: 1: A string to compare against...
# Param: 2: ...this string.
# Returns: $(true) if the two strings are identical.

streq = $(if $(subst x$(1),,x$(2))$(subst x$(2),,x$(1)),$(false),$(true))

# Compares two strings for inequality.
#
# Param: 1: A string to compare against...
# Param: 2: ...this string.
# Returns: $(true) if the two strings are not the same.

strneq = $(call not,$(call streq,$(1),$(2)))

# Escapes single quote for use in echo statements.
#
# Param: 1: A string to escape...
# Returns: ...escaped string.

esc-squote = $(subst $(squote),\$(squote),$(1))

# Includes files, but only if they already exist.
# This prevents remaking targets for which a disk file does not exist.
# This comes from the fact that Make tries to remake a file if:
# - the file doesn't exist, and
# - there is a rule for remaking the file, and
# - the file is listed on 'include' directive.
#
# Param: 1: List of files to include.

define include_if_exists =
include_existing_files = $(wildcard $(1))

ifneq ("$$(include_existing_files)","")
    include $$(include_existing_files)
endif
endef

################################################################################
#                                                                              #
# SECTION: Makefile's environment setup.                                       #
#                                                                              #
################################################################################

# - Eliminate use of the built-in implicit rules, clear out the default list
#   of suffixes for suffix rules and don't define any built-in variables
#   (this increases performance and avoids hard-to-debug behavior).
# - When running multiple jobs in parallel with -j, ensure the output of each job
#   is collected together rather than interspersed with output from other jobs.
# - Warn about undefined variables.

MAKEFLAGS += -r -R --output-sync=target #--warn-undefined-variables

# Shell to use for commands execution.

SHELL := /bin/sh

# Use '>' instead of tab for recipes.
# '>' is easier to distinguish from space than a tab.

.RECIPEPREFIX := >

# Clean Make's default include search path, to make sure nothing unwanted
# is included.

.INCLUDE_DIRS :=

# Avoid funny character set dependencies.

unexport LC_ALL
LC_COLLATE = C
LC_NUMERIC = C
export LC_COLLATE LC_NUMERIC

# Avoid interference with shell env settings.

unexport GREP_OPTIONS

################################################################################
#                                                                              #
# SECTION: Toolchain selection.                                                #
#                                                                              #
################################################################################

ifndef $(CROSS_COMPILE)
    CROSS_COMPILE = arm-none-eabi-
endif

ifndef $(CC)
    CC = $(CROSS_COMPILE)gcc
endif

ifndef $(CXX)
    CXX = $(CROSS_COMPILE)g++
endif

ifndef $(AS)
    AS = $(CC)
endif

ifndef $(LD)
    LD = $(CC)
endif

ifndef $(SIZE)
    SIZE = $(CROSS_COMPILE)size
endif

################################################################################
#                                                                              #
# SECTION: Files and paths.                                                    #
#                                                                              #
################################################################################

# Source files list. Redefine 'SOURCES' variable to 'sources' to comply
# with (this) Makefile Coding Standard.

sources := $(SOURCES)

# Directory for build artifacts. The path provided by the user is sanitized
# to remove possible hard-to-debug errors.

builddir := $(abspath $(BUILDDIR))
builddir := $(patsubst $(CURDIR)/%,%,$(builddir))

# Create build directory only if it does not exist yet.
ifneq ($(MAKECMDGOALS),clean)
    $(shell mkdir -p $(builddir))
endif

# Compiled and linked executable file name.

TARGET_ELF := $(addprefix $(builddir)/,$(PROJECT).elf)

# Executable's map file name.

TARGET_MAP := $(addprefix $(builddir)/,$(PROJECT).map)

# Stack usage analysis report files list.

stack_usages := $(addprefix $(builddir)/,$(sources:%=%.su))

# Object files list.

objects := $(addprefix $(builddir)/,$(sources:%=%.o))

# Dependency files list. These files contain information about the relation
# between %.o object and %.h C/C++ header files, derived from C/C++ source
# files. They allow for detecting changes in header files and forcing a rebuild
# of dependent object files if need be.

deps := $(objects:%=%.d)

# List of files storing toolchain command line flags. These files are used
# to detect changes in flags and to force object(s) re-compilation in case
# the flags changed.

cmds := $(objects:%=%.cmd)

# List of phony-object (non-existing) targets. These targets names are used
# as prerequisites for generating %.cmd file for the linker. Basically,
# stripping %.phony from the targets names allows to derive real objects names,
# and the rule for %.cmd does not need to depend on pure %.o.
# The effect is that, the linker command line can be properly written to %.cmd
# file, but no compilation of %.o object file is needed for that purpose.

phony_objects := $(objects:%=%.phony)

# List of phony-source (non-existing) targets. These targets names are used
# as prerequisites for generating %.cmd files for the compiler/assembler.
# Basically, stripping %.phony from the targets names allows to derive real
# sources names and the rule for %.cmd does not need to depend on pure
# (%.c|%.cpp|%.S). The effect is that, the compiler command line can be
# properly written to %.cmd file, but no compilation of (%.c|%.cpp|%.S) source
# file is needed for that purpose.

phony_sources := $(sources:%=%.phony)

# Supported C/C++/ASM source files patterns.

c_patterns := %.c
cxx_patterns := %.cc %.cpp %.cxx
asm_patterns := %.S %.s

# File patterns for phony source files targets.

c_phony_patterns := $(c_patterns:%=%.phony)
cxx_phony_patterns := $(cxx_patterns:%=%.phony)
asm_phony_patterns := $(asm_patterns:%=%.phony)

################################################################################
#                                                                              #
# SECTION: Toolchain command line tweaks.                                      #
#                                                                              #
################################################################################

# From all provided optimization flags, select those applicable to C.

NON_C_OPT_FLAGS := -fno-rtti
C_OPT_FLAGS := $(filter-out $(NON_C_OPT_FLAGS),$(OPT_FLAGS))

# Flags related to arch, optimization and debugging.

C_FLAGS = $(CPU_FLAGS) $(C_OPT_FLAGS) $(DBG_FLAGS)
C_FLAGS += --specs=$(STDLIB_VARIANT).specs
CXX_FLAGS = $(CPU_FLAGS) $(OPT_FLAGS) $(DBG_FLAGS)
CXX_FLAGS += --specs=$(STDLIB_VARIANT).specs
AS_FLAGS = $(CPU_FLAGS) $(OPT_FLAGS) $(DBG_FLAGS)
AS_FLAGS += --specs=$(STDLIB_VARIANT).specs
LD_FLAGS = $(CPU_FLAGS) $(OPT_FLAGS) $(DBG_FLAGS)
LD_FLAGS += --specs=nosys.specs --specs=$(STDLIB_VARIANT).specs

# Prefix $(INCLUDES) and $(DEFINES) with -I and -D respectively.

ifneq ("$(strip $(INCLUDES))","")
    CPP_FLAGS += $(addprefix -I$(space),$(INCLUDES))
endif

ifneq ("$(strip $(DEFINES))","")
    CPP_FLAGS += $(addprefix -D$(space),$(DEFINES))
endif

# Enable generation of %.d dependencies.
# See compiling/linking section for explanation why %.cmd is removed from $@.

CPP_FLAGS += -MMD -MF $(@:%.cmd=%).d
CLEAN_LIST += $(deps)

# Tailor the way the output executable should be linked.

LD_FLAGS += -static -T $(LINKER_SCRIPT)

# Enable generation of map file.

LD_FLAGS += -Wl,-Map=$(TARGET_MAP)
CLEAN_LIST += $(TARGET_MAP)

# From all provided diagnostics flags, select those applicable to C.

NON_C_DIAGFLAGS := -Wuseless-cast
NON_C_DIAGFLAGS += -Wzero-as-null-pointer-constant
C_FLAGS += $(filter-out $(NON_C_DIAGFLAGS),$(DIAGFLAGS))

# From all provided diagnostics flags, select those applicable to C++.

NON_CXX_DIAGFLAGS := -Wjump-misses-init
NON_CXX_DIAGFLAGS += -Wmissing-prototypes
NON_CXX_DIAGFLAGS += -Wstrict-prototypes
CXX_FLAGS += $(filter-out $(NON_CXX_DIAGFLAGS),$(DIAGFLAGS))

# Use pipes for communication between the various stages of compilation.

C_FLAGS += -pipe
CXX_FLAGS += -pipe
AS_FLAGS += -pipe
LD_FLAGS += -pipe

# Append user-provided custom flags. Appending user flags at the end allows
# for overriding some of the flags that are set by default by this Makefile.

C_FLAGS += $(CFLAGS)
CXX_FLAGS += $(CXXFLAGS)
CPP_FLAGS += $(CPPFLAGS)
AS_FLAGS += $(ASFLAGS)
LD_FLAGS += $(LDFLAGS)
LD_LIBS += $(LDLIBS)

################################################################################
#                                                                              #
# SECTION: C/C++/ASM compilation and executable linking rules.                 #
#                                                                              #
################################################################################

# Commands and commands' arguments for performing particular actions,
# like compiling or linking, are defined in variables named 'cmd_COMMAND',
# where COMMAND stands for 'ld', 'cc', 'as' and so on.
#
# For execution and for saving to %.cmd file, the command shall be passed
# to functions named 'run-cmd' and 'update-cmd', respectively. Only the COMMAND
# part of the variable name shall be passed. For example, to run a command
# defined in a variable named 'cmd_cxx', the following syntax shall be used:
#
#     $(call run-cmd,cxx)
#
# The above call returns C++ compiler command line that can be passed
# to the shell for execution.

# From a list of file names, filter those matching objects, C sources,
# C++ sources and assembler sources, respectively. In addition to the standard
# suffixes (%.o, %.c, etc.), objects/sources file names might end with a %.phony
# suffix as in %.o.phony, %.c.phony, etc., in which case %.phony is removed.
#
# Param: 1: List of file names.
# Returns: List of file names matching object/source file patterns,
#     with %.phony suffix removed.

filter-objects = \
    $(patsubst %.phony,%,$(filter %.o %.o.phony,$(1)))
filter-c-sources = \
    $(patsubst %.phony,%,$(filter $(c_patterns) $(c_phony_patterns),$(1)))
filter-cxx-sources = \
    $(patsubst %.phony,%,$(filter $(cxx_patterns) $(cxx_phony_patterns),$(1)))
filter-asm-sources = \
    $(patsubst %.phony,%,$(filter $(asm_patterns) $(asm_phony_patterns),$(1)))

# For a %.cmd file, return its matching source file.
#
# Param: 1: %.cmd file name.
# Returns: Source file name.

sources-from-cmds = $(patsubst $(builddir)/%.o.cmd,%,$(1))

# For a %.o file, return its matching source file.
#
# Param: 1: %.o file name.
# Returns: Source file name.

sources-from-objects = $(patsubst $(builddir)/%.o,%,$(1))

# Based on the source file type, return command to use to compile the parti-
# cular source file. In addition to the standard suffixes (%.c, %.cpp, etc.),
# source file name might end with a %.phony suffix as in %.o.phony, %.c.phony,
# etc., and a correct command will still be returned. The returned command
# string is formatted such that it can be passed to the 'run-cmd' function.
#
# Param: 1: Source file name.
# Returns: 'run-cmd'-formatted command string.

define cmd_from-source =
$(if $(call filter-c-sources,$(1)),$\
    cc,$\
$(if $(call filter-cxx-sources,$(1)),$\
    cxx,$\
$(if $(call filter-asm-sources,$(1)),$\
    as,$\
)))
endef

# Select proper linker command. If at least one of the sources is of C++ type,
# use $(CXX), otherwise, use $(CC).

ifeq ("$(LD)","$(CC)")
    ifneq ("$(filter $(cxx_patterns),$(sources))","")
        cmd_ld = $(CXX)
    else
        cmd_ld = $(CC)
    endif
else
    cmd_ld = $(LD)
endif

# Linker's final command line.
# Input files are filtered so that only %.o object files are fed to the linker.
# (There might be other file types in the prerequisites list.) Also, %.phony is
# removed from input file names and %.cmd is removed from output file name:
# this allows for the same linker command line cmd_ variable to be used both
# in link and in %.cmd generation rules.

cmd_ld += $(call filter-objects,$^) -o $(@:%.cmd=%) $(LD_FLAGS) $(LD_LIBS)

# Rule for linking.

$(TARGET_ELF): $(objects) $(LINKER_SCRIPT) $(TARGET_ELF).cmd
>   $(debug-rule)$(call run-cmd,ld)

CLEAN_LIST += $(TARGET_ELF)

# Rule for saving linker's complete command line to %.cmd file.
# Phony objects names in the prerequisites list are used to derive real
# objects names, thusly the complete linker command line is reconstructed
# and it matches exactly the command line used in the rule for linking.

.PRECIOUS: $(TARGET_ELF).cmd
.PHONY: $(phony_objects)

$(TARGET_ELF).cmd: $(phony_objects)
>   $(debug-rule)$(call update-cmd,ld)

CLEAN_LIST += $(TARGET_ELF).cmd

# Include %.cmd command line file for the linker, if it already exists.
# If not, then there's a rule to create it.

ifneq ($(MAKECMDGOALS),clean)
    $(eval $(call include_if_exists,$(TARGET_ELF).cmd))
endif

# C/C++ compiler and ASM assembler final command lines.
# Input files are filtered so that only source files matching supported
# C/C++/ASM file patterns are fed to the compiler. (There might be other file
# types in the prerequisites list.) Also, %.phony is removed from input file
# names and %.cmd is removed from output file name: this allows for the same
# compiler command line cmd_ variable to be used both in compile and in %.cmd
# generation rules.

cmd_cc  = $(CC) -x c \
    -c $(call filter-c-sources,$<) -o $(@:%.cmd=%) $(C_FLAGS) $(CPP_FLAGS)
cmd_cxx = $(CXX) -x c++ \
    -c $(call filter-cxx-sources,$<) -o $(@:%.cmd=%) $(CXX_FLAGS) $(CPP_FLAGS)
cmd_as  = $(AS) -x assembler-with-cpp \
    -c $(call filter-asm-sources,$<) -o $(@:%.cmd=%) $(AS_FLAGS) $(CPP_FLAGS)

.SECONDEXPANSION:

# Rule for compiling C/C++ and assembling ASM.
# The recipe is executed separately for each object listed in the targets list.
# Thanks to the second expansion, the '$$' prerequisites are computed
# in a kind of middle-expansion pass, that is after the targets are expanded
# but before the recipe is executed. In other words, '$$' prerequisites are not
# expanded at the time the '$' targets are expanded. This allows to first learn
# about *real* names of the targets, and then, to compute the prerequisites
# based on that real names of the targets.

$(objects): $$(call sources-from-objects,$$@) $$(addsuffix .cmd,$$@)
>   $(debug-rule)$(call run-cmd,$(call cmd_from-source,$<))

CLEAN_LIST += $(objects)
CLEAN_LIST += $(stack_usages)

# Rule for saving compiler's complete command line to %.cmd file.
# Phony sources names in the prerequisites list are used to derive real
# sources names, thusly the complete compiler command line is reconstructed
# and it matches exactly the command line used in the rule for compiling.
# See the rule for compiling for an explanation of second expansion
# and the use of '$$' in the prerequisites list.

.PRECIOUS: $(cmds)
.PHONY: $(phony_sources)

$(cmds): $$(addsuffix .phony,$$(call sources-from-cmds,$$@))
>   $(debug-rule)$(call update-cmd,$(call cmd_from-source,$<))

CLEAN_LIST += $(cmds)

# If exist, include %.cmd command line files used to create object files.
# If the files don't exist, there's a rule to create them.

ifneq ($(MAKECMDGOALS),clean)
    $(eval $(call include_if_exists,$(cmds)))
endif

# Include %.d dependencies of the object files, if they already exist.
# If not, '-MMD' switch to GCC will create them.

ifneq ($(MAKECMDGOALS),clean)
    $(eval $(call include_if_exists,$(deps)))
endif

################################################################################
#                                                                              #
# SECTION: Clean rules.                                                        #
#                                                                              #
################################################################################

# Command to use for removing build artifacts.

cmd_clean = rm -f $(CLEAN_LIST)

# Rule for cleaning.

.PHONY: clean
clean:
>   $(call run-cmd,clean)
>   @rmdir $(builddir) 2> /dev/null || true

################################################################################
#                                                                              #
# SECTION: Executable transformation and details inspection rules.             #
#                                                                              #
################################################################################

# Command to use for obtaining target size.

cmd_size = $(SIZE) $(TARGET_ELF)

.PHONY: size
size: $(TARGET_ELF)
>   $(call run-cmd,size)

################################################################################
#                                                                              #
# Quiet/verbose modes.                                                         #
#                                                                              #
################################################################################

# Messages to display in quiet mode.
# Strip build dir where applicable to improve readability.

quiet_cmd_cc    = CC     $(patsubst $(builddir)/%,%,$@)
quiet_cmd_cxx   = CXX    $(patsubst $(builddir)/%,%,$@)
quiet_cmd_as    = AS     $(patsubst $(builddir)/%,%,$@)
quiet_cmd_ld    = LINK   $(patsubst $(builddir)/%,%,$@)
quiet_cmd_clean = CLEAN  $(PROJECT)
quiet_cmd_size  = SIZE   $(TARGET_ELF)

# Use 'make V=1' to see the full commands, otherwise
# be less verbose to put more focus on warnings.

ifeq "$(V)" "1"
    quiet :=
else
    quiet := quiet_
endif

# TODO.

run-cmd = @set -e; $(cmd_is-defined); $(echo-cmd); $(cmd_$(1))

# Update, or if it doesn't already exist, create %.cmd file storing
# the toolchain's complete command line. The file is only 'touched' if
# it doesn't exist or the command line stored inside is different from
# the currently computed command line for a particular executable
# or object file.
#
# Context: Recipe.
# Param: @: Rule's target (automatic variable). This shall be a %.cmd file
#     name to be updated. Note that this file name shall have a corresponding
#     executable or object file name. By a 'corresponding' is meant a file name
#     that will exactly match '$@', provided that '%.cmd' suffix is removed
#     from '$@'.
# Param: 1: Command to be saved, without 'cmd_' prefix.

define update-cmd =
$(if $(call cmd_is-defined,$(1)),$\
    $(if $(call strneq,$(cmd_$(1)),$(cmd_$(@:%.cmd=%))),$(call save-cmd,$(1))))
endef

# Save toolchain's complete command line to %.cmd file.
#
# Context: Recipe.
# Param: @: Rule's target (automatic variable). This shall be a %.cmd file
#     name to which to store the command line. Note that this file name shall
#     have a corresponding executable or object file name. By a 'corresponding'
#     is meant a file name that will exactly match '$@', provided that '%.cmd'
#     suffix is removed from '$@'.
# Param: 1: Command to be saved, without 'cmd_' prefix.

save-cmd = $(file > $@,cmd_$(@:%.cmd=%) := $(cmd_$(1)))

# TODO.

cmd_is-defined = $(if $(cmd_$(1)),true,$(error cmd_$(1) is not defined))

# TODO.

echo-cmd = \
    echo $(if $(quiet),'  ')$(if $($(quiet)cmd_$(1)),$(quiet_cmd),$(verbose_cmd))

# TODO.

quiet_cmd = $(call esc-squote,$($(quiet)cmd_$(1)))

# TODO.

verbose_cmd = $(call esc-squote,$(cmd_$(1)))

################################################################################
#                                                                              #
# SECTION: Debug rules.                                                        #
#                                                                              #
################################################################################

# Prints target name and a prerequisites list.
#
# Context: Recipe.
# Param: $@: Rule's target (automatic variable).
# Param: $^: Rule's prerequisites (automatic variable).

debug-rule = $(if $(false),$(info Debug: [$@]: [$^]))

# Prints variable name and its value.
# The variable name is based on the stem ($*) with which a rule matches.
#
# Context: Recipe.
# Param: $*: Rule target's stem (automatic variable).

define debug-print =
$(if $(call not,$(filter undefined,$(origin $*))),$\
    $(info Debug: [$*]=[$($*)]),$\
    $(error [$*] is not defined))
endef

# Dummy target to use as prerequisite for 'print-%' target,
# so that '$^' / '^<' automatic variables have some non-empty value.

.PHONY: debug-print-dummy-prereq.(o,c,etc)
debug-print-dummy-prereq.(o,c,etc):;

# Rule for printing selected variable's value. Use as follows:
# $ make debug-print-CFLAGS

.PHONY: debug-print-%
debug-print-%: debug-print-dummy-prereq.(o,c,etc)
>   $(debug-print)

# Catch-all rule for header files. If this rule is executed, the specified
# header file does not exist and a user friendly warning message is printed
# (as opposed to the usual "No rule to make target 'x', needed by 'y'").
# Missing header file does not necessarily mean an error. Situation like
# this might happen for example if %.h has been renamed, but the old name
# is still listed as prerequisite in %.d dependency file. Such a missing
# header should not make the whole compilation to fail. If the header with
# the old name is *really* needed, then the compiler will signal it by failing.

%.h:
>   $(warning Header file does not exist: $@)

# Catch-all rule for source files. If this rule is executed, the specified
# source file does not exist and a user friendly error message is printed
# (as opposed to the usual "No rule to make target 'x', needed by 'y'").

$(sources):
>   $(error Source file does not exits: $@)

################################################################################
#                                                                              #
# SECTION: Help.                                                               #
#                                                                              #
################################################################################

define helptext :=
Help for GNU Arm Embedded Toolchain project Makefile
endef

.PHONY: help
help:
>   @echo -e '$(subst $(newline),\n,$(helptext))'

################################################################################
#                                                                              #
# SECTION: (This) Makefile Coding Standard.                                    #
#                                                                              #
################################################################################

# - First section of the file is user facing. It shall contain no code,
#   but only variables defining the build process.
# - Variables names shall be:
#   - UPPER CASE IN THE FIRST (USER FACING) SECTION,
#   - lower case in the code sections.
# - User functions and templates shall use '-' to separate words.
# - Variables shall use '_' to separate words.
# - Templates names shall be enclosed in '<>' (borrowed from C++).
# - Automatic variables shall be used whenever possible.
# - Line lengths should be limited to 80 columns,
#   with 100 columns being a hard limit.

################################################################################
#                                                                              #
# SECTION: References.                                                         #
#                                                                              #
################################################################################

# - https://github.com/abcminiuser/dmbs/
# - https://www.kernel.org/doc/html/latest/kbuild/
# - https://www.gnu.org/software/make/manual/
# - https://sourceforge.net/projects/gmsl/

################################################################################
#                                                                              #
# SECTION: TODO/BUGS.                                                          #
#                                                                              #
################################################################################

# - A handful of fuctions require description (functions marked 'TODO.').
# - In function description, use imperative mood for the first verb.
# - In function description, remove '$' from parameters.
# - Reorder functions: higher level first, lower level (details) next.
# - Rename 'cmds' to dotcmds to differentiate from 'cmd_X'.
# - Allow enabling/disabling debug messages, e.g. with 'V=2'
#   and enable 'debug-rule' function.
# - Extend debug messages, e.g. print what files are or aren't include'd.
# - Ensure build directory does not contain spaces nor colons (import from kbuild).
#   Improve builddir sanitianization if feasible.
# - Improve builddir creation and removal. It's not very elegant now.
# - Create sub-directories required for object files. For now, only top
#   builddir is supported, which means that sources cannot be nested in
#   sub-directories, but need to be in the same single directory.
# - If the command line goal ends in (.o|.cmd) prefix that goal with build
#   directory path so that proper target can be built.
# - Test if SOURCES contain correct files.
# - Sanitize SOURCES with for example realpath.
# - Fix 'undefined variable' warnings and enable
#   'MAKEFLAGS += --warn-undefined-variables'.
# - Make sure variables appended to compiler/assembler/linker command lines
#   do not add extra space character (e.g. if the variable being appended
#   is empty).
# - After running '$ make clean build/maic.c.o', 'build/maic.c.o.cmd' is not
#   present, but it should be. This is related to:
#   - 'ifneq ($(MAKECMDGOALS),clean)' not including %.cmd when 'clean' goal
#     is given on the command line,
#   - the problem with 'include' directive and automatic remaking of Makefiles
#     (https://www.gnu.org/software/make/manual/html_node/Remaking-Makefiles.html)
#   - if 'ifneq ($(MAKECMDGOALS),clean)' is not used, then when 'clean' goal is
#     given on command line, then Make tries to remake %.cmd targets, because
#     they are treated as include'd Makefiles and Make tries to remake them,
#   - further example: running 'make debug-print-CC' causes %.c recipes to
#     be executed, this is most probably caused by include'ing %.cmd files.
# - Generate %.hex file from %.elf.
# - Generate asm listings from C/C++ source files.
# - Add user facing variables: C_STANDARD/CXX_STANDARD for handling C and C++
#   standards.
# - Add some inspection targets as found at the bottom of
#   https://github.com/abcminiuser/dmbs/blob/master/DMBS/gcc.mk
# - Objects paths computed from sources paths might contain '../' in names,
#   if for example a source file from higher level directory is listed in
#   SOURCES as ../lib/md5.c. To solve issue with such named objects being
#   incorrectly placed out of build directory, before prefixing object names
#   with the build directory, abs path for an object should be computed.
#   Then this abs path should be prefixed to the object path. For readability
#   reasons, it is worth to first compute shortest unique objects names paths,
#   that is to remove the common path component from objects names, before
#   prefixing objects with build directory path.
# - $ gcc -Wbad-function-cast -Wall -c -Q -O3 --help=warnings allows to find
#   out which warning flags are enabled for particular command line. Substituting
#   'warnings' for 'optimizers' allows for finding out which optimization flags
#   are enabled taking into account previous command line switches, like -O2.
#   For this to work, the different flags should precede --help=. Use this
#   to detect what else DIAGFLAGS can be switched on and which DIAGFLAGS
#   do not exist for a particular compiler version, so that they can be removed
#   dynamically from flags passed to the toolchain. See 'man gcc' about '--help='.
# - Normalize upper/lower case letters in variables names.
# - INCLUDES and DEFINES do not work with spaces within a value.
#   Find a way to make it work (a must for defines DEFINES).
# - Rebuild on SOURCES change?
# - Support %.o in sources for pre-built objects?
# - Support %.a in sources for pre-built libraries?
# - Add gnu-build-id?
# - Allow per source file C/CXX/AS-FLAGS.
# - Reproducible builds.
# - Write 'help'.
# - Write tests.
# - Allow disabling compiler flag by prefixing it with '!'.
# - Make prefixing compiler flag with '?' be only applied if the particular
#   version of the compiler supports it. For example, newer version of GCC
#   have warning flags that are not available in earlier version, and applying
#   such flag causes compiler to exit with error.
# - Add support for LLVM/Clang, IAR and Keil toolchains.
# - (Re)Compile GNU Arm Embedded Toolchain with support for '-fno-short-enums'.
#   This best be a separate *libc* version, similarly as with 'nano' version.
