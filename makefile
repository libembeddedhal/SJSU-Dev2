# Allow settiing a project name from the environment, default to firmware.
# Only affects the name of the generated binary.
# TODO(#82): Set this from the directory this makefile is stored in
PROJ    ?= firmware
# Affects what DBC is generated for SJSUOne board
ENTITY  ?= DBG
# Optimization level
OPT=0
# Cause compiler warnings to become errors.
# Used in presubmit checks to make sure that the codebase does not include
# warnings
WARNINGS_ARE_ERRORS ?=
# IMPORTANT: Be sure to source env.sh to access these via the PATH variable.
DEVICE_CC      = arm-none-eabi-gcc
DEVICE_CPPC    = arm-none-eabi-g++
DEVICE_OBJDUMP = arm-none-eabi-objdump
DEVICE_SIZEC   = arm-none-eabi-size
DEVICE_OBJCOPY = arm-none-eabi-objcopy
DEVICE_NM      = arm-none-eabi-nm
# Set of tests you would like to run. Text must be surrounded by [] and be a set
# comma deliminated.
#
#   Example of running only i2c and adc tests with the -s flag to show
#   successful assertions:
#
#         make run-test TEST_ARGS="-s [i2c,adc]"
#
TEST_ARGS ?=
# IMPORTANT: GCC must be accessible via the PATH environment variable
HOST_CC        ?= $(SJCLANG)/clang
HOST_CPPC      ?= $(SJCLANG)/clang++
HOST_OBJDUMP   ?= $(SJCLANG)/llvm-objdump
HOST_SIZEC     ?= $(SJCLANG)/llvm-size
HOST_OBJCOPY   ?= $(SJCLANG)/llvm-objcopy
HOST_NM        ?= $(SJCLANG)/llvm-nm

ifeq ($(MAKECMDGOALS), test)
CC      = $(HOST_CC)
CPPC    = $(HOST_CPPC)
OBJDUMP = $(HOST_OBJDUMP)
SIZEC   = $(HOST_SIZEC)
OBJCOPY = $(HOST_OBJCOPY)
NM      = $(HOST_NM)
else
CC      = $(DEVICE_CC)
CPPC    = $(DEVICE_CPPC)
OBJDUMP = $(DEVICE_OBJDUMP)
SIZEC   = $(DEVICE_SIZEC)
OBJCOPY = $(DEVICE_OBJCOPY)
NM      = $(DEVICE_NM)
endif

# shell echo must be used to ensure that the \x1B makes it into the variable
# simply doing YELLOW=\x1B[33;1m works on Linux but the forward slash is omitted
# on mac.
YELLOW=$(shell echo "\x1B[33;1m")
RESET=$(shell echo "\x1B[0m")
GREEN=$(shell echo "\x1B[32;1m")

CLANG_TIDY  = $(SJCLANG)/clang-tidy

# Internal build directories
BUILD_DIR = build
TEST_DIR  = $(BUILD_DIR)/test

ifeq ($(MAKECMDGOALS), bootloader)
BIN_DIR   = $(BUILD_DIR)/bootloader
else
BIN_DIR   = $(BUILD_DIR)/application
endif

ifeq ($(MAKECMDGOALS), test)
OBJ_DIR   = $(TEST_DIR)/compiled
else
OBJ_DIR   = $(BIN_DIR)/compiled
endif

DBC_DIR   = $(BUILD_DIR)/can-dbc
COVERAGE  = $(BUILD_DIR)/coverage
LIB_DIR   = $(SJLIBDIR)
FIRMWARE  = $(SJBASE)/firmware
TOOLS     = $(SJBASE)/tools
COMPILED_HEADERS  = $(BUILD_DIR)/headers
CURRENT_DIRECTORY	= $(shell pwd)
# Source files folder
SOURCE    = source
define n


endef

ifndef SJDEV
$(error $n$n=============================================$nSJSU-Dev2 environment variables not set.$nPLEASE run "source env.sh"$n=============================================$n$n)
endif

#########
# FLAGS #
#########
CORTEX_M4F = -mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16 \
			       -fabi-version=0 \
			       -finstrument-functions-exclude-file-list=L0_LowLevel
OPTIMIZE  = -O$(OPT) -fmessage-length=0 -ffunction-sections -fdata-sections \
            -fno-exceptions -fomit-frame-pointer
CPPOPTIMIZE = -fno-rtti
DEBUG     = -g
WARNINGS  = -Wall -Wextra -Wshadow -Wlogical-op -Wfloat-equal \
            -Wdouble-promotion -Wduplicated-cond -Wswitch \
            -Wnull-dereference -Wformat=2 \
            -Wundef -Wconversion -Wsuggest-final-types \
            -Wsuggest-final-methods $(WARNINGS_ARE_ERRORS)
CPPWARNINGS = -Wold-style-cast -Woverloaded-virtual -Wsuggest-override \
              -Wuseless-cast $(WARNINGS_ARE_ERRORS)
DEFINES   = -DARM_MATH_CM4=1 -D__FPU_PRESENT=1U
DISABLED_WARNINGS = -Wno-main -Wno-variadic-macros
# stdlib=libc++ : tell clang to ignore GCC standard libs
INCLUDES  = -I"$(CURRENT_DIRECTORY)/" \
			-I"$(LIB_DIR)/" \
			-I"$(LIB_DIR)/L0_LowLevel/SystemFiles" \
			-idirafter"$(LIB_DIR)/third_party/" \
			-idirafter"$(LIB_DIR)/third_party/printf" \
			-idirafter"$(LIB_DIR)/third_party/FreeRTOS/Source" \
			-idirafter"$(LIB_DIR)/third_party/FreeRTOS/Source/trace" \
			-idirafter"$(LIB_DIR)/third_party/FreeRTOS/Source/include" \
			-idirafter"$(LIB_DIR)/third_party/FreeRTOS/Source/portable" \
			-idirafter"$(LIB_DIR)/third_party/FreeRTOS/Source/portable/GCC/ARM_CM4F"
COMMON_FLAGS = $(CORTEX_M4F) $(OPTIMIZE) $(DEBUG) $(WARNINGS) $(DEFINES) \
               $(DISABLED_WARNINGS)

CFLAGS_COMMON = $(COMMON_FLAGS) $(INCLUDES) -MMD -MP -c

ifeq ($(MAKECMDGOALS), test)
CFLAGS = -fprofile-arcs -fPIC -fexceptions -fno-inline -fno-builtin \
				 -fprofile-instr-generate -fcoverage-mapping \
         -fno-elide-constructors -ftest-coverage -fno-omit-frame-pointer \
				 -fsanitize=address -stdlib=libc++ \
				 -Wconversion -Wextra -Wall \
				 -Wno-sign-conversion -Wno-format-nonliteral \
				 -Winconsistent-missing-override -Wshadow -Wfloat-equal \
         -Wdouble-promotion -Wswitch -Wnull-dereference -Wformat=2 \
         -Wundef -Wold-style-cast -Woverloaded-virtual \
				 $(WARNINGS_ARE_ERRORS) \
				 -D HOST_TEST=1 -D SJ2_BACKTRACE_DEPTH=1024 \
				 $(INCLUDES) $(DEFINES) $(DEBUG) $(DISABLED_WARNINGS) \
         -O0 -MMD -MP -c
CPPFLAGS = $(CFLAGS)
else
CFLAGS = $(CFLAGS_COMMON)
CPPFLAGS = $(CFLAGS) $(CPPWARNINGS) $(CPPOPTIMIZE)
endif

ifeq ($(MAKECMDGOALS), bootloader)
LINKER = $(LIB_DIR)/LPC4078_bootloader.ld
CFLAGS += -D BOOTLOADER=1
endif
# NOTE: DO NOT LINK -finstrument-functions into test build when using clang and
# clang std libs (libc++) or it will result in a metric ton of undefined linker
# errors.
ifeq ($(MAKECMDGOALS), application)
LINKER = $(LIB_DIR)/LPC4078_application.ld
CFLAGS += -D APPLICATION=1
CFLAGS += -finstrument-functions
endif

LINKFLAGS = $(COMMON_FLAGS) \
    -T $(LINKER) \
    -Wl,--gc-sections \
		-Wl,-Map,"$(MAP)" \
    -specs=nano.specs
##############
# Test files #
##############
FILE_EXCLUDES = grep -v  \
				-e "$(LIB_DIR)/third_party/" \
				-e "$(LIB_DIR)/L0_LowLevel/SystemFiles" \
				-e "$(LIB_DIR)/L0_LowLevel/LPC40xx.h" \
				-e "$(LIB_DIR)/L0_LowLevel/FreeRTOSConfig.h"
# Find all files that end with "_test.cpp"
SOURCE_TESTS  = $(shell find $(SOURCE) \
                         -name "*_test.cpp" \
                         2> /dev/null)
# Find all library that end with "_test.cpp"
LIBRARY_TESTS = $(shell find "$(LIB_DIR)" -name "*_test.cpp" | \
						    $(FILE_EXCLUDES))
TESTS = $(SOURCE_TESTS) $(LIBRARY_TESTS)
OMIT_LIBRARIES = $(shell find "$(LIB_DIR)" \
                         -name "startup.cpp" -o \
                         -name "*.cpp" \
                         -path "$(LIB_DIR)/third_party/*" -o \
						             -path "$(LIB_DIR)/third_party/*")
OMIT_SOURCES   = $(shell find $(SOURCE) -name "main.cpp")
OMIT = $(OMIT_LIBRARIES) $(OMIT_SOURCES)
################
# Source files #
################
DBC_BUILD     = $(DBC_DIR)/generated_can.h
LIBRARY_FILES = $(shell find "$(LIB_DIR)" \
                         -name "*.c" -o \
                         -name "*.cpp")
# Remove all test files from LIBRARY_FILES
LIBRARIES     = $(filter-out $(LIBRARY_TESTS), $(LIBRARY_FILES))
SOURCE_FILES  = $(shell find $(SOURCE) \
                         -name "*.c" -o \
                         -name "*.s" -o \
                         -name "*.S" -o \
                         -name "*.cpp" \
                         2> /dev/null)
SOURCE_HEADERS  = $(shell find $(SOURCE) \
                         -name "*.h" -o \
                         -name "*.hpp" \
                         2> /dev/null)
PRINTF_3P_LIBRARY = $(shell find "$(LIB_DIR)/third_party/printf" \
                         -name "*.cpp" 2> /dev/null)
##############
# Lint files #
##############
LINT_FILES      = $(shell find $(FIRMWARE) \
                         -name "*.h"   -o \
                         -name "*.hpp" -o \
                         -name "*.c"   -o \
                         -name "*.cpp" | \
						             $(FILE_EXCLUDES) \
                         2> /dev/null)
LINT_FILES_PHONY = $(LINT_FILES:=.lint)
# Remove all test files from SOURCE_FILES
SOURCES     = $(filter-out $(SOURCE_TESTS), $(SOURCE_FILES))
ifeq ($(MAKECMDGOALS), test)
COMPILABLES = $(filter-out $(OMIT), $(TESTS) $(LIBRARIES) $(SOURCES)) \
              $(PRINTF_3P_LIBRARY)
else
COMPILABLES = $(LIBRARIES) $(SOURCES)
endif
###############
# Ouput Files #
###############
# $(patsubst %.cpp,%.o, LIST)    : Replace .cpp -> .o
# $(patsubst %.c,%.o, LIST)      : Replace .c -> .o
# $(patsubst src/%,%, LIST)      : Replace src/path/file.o -> path/file.o
# $(addprefix $(OBJ_DIR)/, LIST) : Add OBJ DIR to path
#                                  (path/file.o -> obj/path/file.o)
# NOTE: the extra / for obj_dir is necessary to fully quaify the path from root.
OBJECT_FILES = $(addprefix $(OBJ_DIR)/, \
                    $(patsubst %.S,%.o, \
                        $(patsubst %.s,%.o, \
                            $(patsubst %.c,%.o, \
                                $(patsubst %.cpp,%.o, \
                                    $(COMPILABLES) \
                                ) \
                            ) \
                        ) \
                    ) \
                )
EXECUTABLE = $(BIN_DIR)/$(PROJ).elf
BINARY     = $(EXECUTABLE:.elf=.bin)
HEX        = $(EXECUTABLE:.elf=.hex)
LIST       = $(EXECUTABLE:.elf=.lst)
SIZE       = $(EXECUTABLE:.elf=.siz)
MAP        = $(EXECUTABLE:.elf=.map)
TEST_EXEC  = $(TEST_DIR)/tests.exe
TEST_FRAMEWORK = $(LIB_DIR)/L5_Testing/testing_frameworks.hpp.gch

# This line allows the make to rebuild if header file changes.
# This is feature and not a bug, otherwise updates to header files do not
# register as an update to the source code.
DEPENDENCIES = $(OBJECT_FILES:.o=.d)
-include       $(DEPENDENCIES)
# Tell make to delete built files it has created if an error occurs
.DELETE_ON_ERROR:
# Tell make that the default recipe is the default
.DEFAULT_GOAL := default
# Tell make that these recipes don't have a end product
.PHONY: build cleaninstall telemetry monitor show-lists clean flash telemetry \
        presubmit openocd debug multi-debug default
print-%  : ; @echo $* = $($*)

# When the user types just "make" this should appear to them
help:
	@echo "List of available targets:"
	@echo
	@echo "    build        - builds firmware project"
	@echo "    bootloader   - builds firmware using bootloader linker"
	@echo "    help         - shows this menu"
	@echo "    flash        - builds and installs firmware on to SJOne board"
	@echo "    telemetry    - will launch telemetry interface"
	@echo "    clean        - cleans project folder"
	@echo "    cleaninstall - cleans, builds, and installs firmware"
	@echo "    show-lists   - Shows all object files that will be compiled"
	@echo "    presubmit    - run presubmit checks script"
	@echo "    openocd      - run openocd with the sjtwo.cfg file"
	@echo "    debug        - run arm gdb with current projects .elf file"
	@echo "    multi-debug  - run multiarch gdb with current projects .elf file"
	@echo

# Shows the help menu without any targets specified
default: help
bootloader: build
# Build recipe
application: build
build: $(DBC_DIR) $(OBJ_DIR) $(BIN_DIR) $(LIST) $(HEX) $(BINARY) $(SIZE)
# Clean working build directory by deleting the build folder
clean:
	rm -fR $(BUILD_DIR)
# Build application and flash board
flash: build
	@bash -c "\
	source $(TOOLS)/Hyperload/modules/bin/activate && \
	python $(TOOLS)/Hyperload/hyperload.py -b 576000 -c 48000000 -a clocks -d $(SJDEV) $(HEX)"
# Complete rebuild and flash installation
cleaninstall: clean build flash
# Run telemetry
telemetry:
	@bash -c "\
	source $(TOOLS)/Telemetry/modules/bin/activate && \
	python2.7 $(TOOLS)/Telemetry/telemetry.py"
# Build test file
test: $(COVERAGE) $(TEST_EXEC)
# Run test file and generate code coverage report
run-test: $(COVERAGE)
	@$(TEST_EXEC) $(TEST_ARGS)
	@gcovr --root="$(FIRMWARE)/" --keep --object-directory="$(BUILD_DIR)/" \
		-e "$(LIB_DIR)/newlib" \
		-e "$(LIB_DIR)/third_party" \
		-e "$(LIB_DIR)/L5_Testing" \
		--html --html-details --gcov-executable="llvm-cov gcov" \
		-o $(COVERAGE)/coverage.html
# Evaluate library files and check them for linting errors.
lint:
	@python2.7 $(TOOLS)/cpplint/cpplint.py $(LINT_FILES)
# Evaluate library files for proper code naming conventions
tidy: $(LINT_FILES_PHONY)
	@printf '$(GREEN)Tidy Evaluation Complete. Everything clear!$(RESET)\n'
# Run presumbission tests
presubmit:
	$(TOOLS)/presubmit.sh
# Start an openocd jtag debug session for the sjtwo development board
openocd:
	openocd -f $(FIRMWARE)/debug/sjtwo.cfg
# Start gdb for arm and connect to openocd jtag debugging session
debug:
	arm-none-eabi-gdb -ex "target remote :3333" $(EXECUTABLE)
# Start gdb just like the debug target, but using gdb-multiarch
# gdb-multiarch is perferable since it supports python in its .gdbinit file
multi-debug:
	gdb-multiarch -ex "target remote :3333" $(EXECUTABLE)
# Debug recipe to show internal list contents
show-lists:
	@echo "=========== OBJECT FILES ============"
	@echo $(OBJECT_FILES)
	@echo "===========  TEST FILES  ============"
	@echo $(TESTS)
	@echo "===========  LIBRARIES   ============"
	@echo $(LIBRARIES)
	@echo "===========   SOURCES   ============"
	@echo $(SOURCES)
	@echo "=========== COMPILABLES ============"
	@echo $(COMPILABLES)
	@echo "=========== OMIT ============"
	@echo $(OMIT)
	@echo "===========   FLAGS   =============="
	@echo $(CFLAGS)
	@echo "=========== TEST FLAGS =============="
	@echo $(TEST_CFLAGS)
	@echo "=========== CLANG TIDY BIN PATH =============="
	@echo $(CLANG_TIDY)
	@echo "=========== OMIT_LIBRARIES =============="
	@echo $(OMIT_LIBRARIES)

$(HEX): $(EXECUTABLE)
	@printf '$(YELLOW)Generating Hex Image $(RESET)   : $@ '
	@$(OBJCOPY) -O ihex "$<" "$@"
	@printf '$(GREEN)Hex Generated!$(RESET)\n'

$(BINARY): $(EXECUTABLE)
	@printf '$(YELLOW)Generating Binary Image $(RESET): $@ '
	@$(OBJCOPY) -O binary "$<" "$@"
	@printf '$(GREEN)Binary Generated!$(RESET)\n'

$(SIZE): $(EXECUTABLE)
	@echo ' '
	@echo 'Showing Image Size Information: '
	@$(SIZEC) --format=berkeley "$<"
	@echo ' '

$(LIST): $(EXECUTABLE)
	@printf '$(YELLOW)Generating Disassembly$(RESET)  : $@ '
	@$(OBJDUMP) --disassemble --all-headers --source --demangle --wide "$<" > "$@"
	@printf '$(GREEN)Disassembly Generated!$(RESET)\n'

$(EXECUTABLE): $(OBJECT_FILES)
	@printf '$(YELLOW)Linking Executable $(RESET)     : $@ '
	@mkdir -p "$(dir $@)"
	@$(CPPC) $(LINKFLAGS) -o "$@" $(OBJECT_FILES)
	@printf '$(GREEN)Executable Generated!$(RESET)\n'

$(OBJ_DIR)/%.o: %.cpp
	@printf '$(YELLOW)Building file (C++) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CPPC) $(CPPFLAGS) -std=c++17 -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@printf '$(GREEN)DONE!$(RESET)\n'

$(OBJ_DIR)/%.o: %.c
	@printf '$(YELLOW)Building file ( C ) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CC) $(CFLAGS) -std=gnu11 -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@printf '$(GREEN)DONE!$(RESET)\n'

$(OBJ_DIR)/%.o: %.s
	@printf '$(YELLOW)Building file (Asm) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CC) $(CFLAGS) -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@printf '$(GREEN)DONE!$(RESET)\n'

$(OBJ_DIR)/%.o: %.S
	@printf '$(YELLOW)Building file (Asm) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CC) $(CFLAGS) -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@printf '$(GREEN)DONE!$(RESET)\n'

$(OBJ_DIR)/%.o: $(LIB_DIR)/%.cpp
	@printf '$(YELLOW)Building file (C++) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CPPC) $(CPPFLAGS) -std=c++17 -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@printf '$(GREEN)DONE!$(RESET)\n'

$(OBJ_DIR)/%.o: $(LIB_DIR)/%.c
	@printf '$(YELLOW)Building file ( C ) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CC) $(CFLAGS) -std=gnu11 -MF"$(@:%.o=%.d)" -MT"$(@)" -o "$@" "$<"
	@printf '$(GREEN)DONE!$(RESET)\n'

$(DBC_BUILD):
	python2.7 "$(LIB_DIR)/$(DBC_DIR)/dbc_parse.py" -i "$(LIB_DIR)/$(DBC_DIR)/243.dbc" -s $(ENTITY) > $(DBC_BUILD)

$(OBJ_DIR) $(BIN_DIR) $(DBC_DIR):
	@echo 'Creating Folder: $@'
	mkdir -p "$@"

$(COVERAGE):
	mkdir -p $(COVERAGE)

$(TEST_EXEC): $(TEST_FRAMEWORK) $(OBJECT_FILES)
	@printf '$(YELLOW)Linking Test Executable $(RESET) : $@ '
	@mkdir -p "$(dir $@)"
	@$(CPPC) -fprofile-arcs -fPIC -fexceptions -fno-inline \
           -fno-inline-small-functions -fno-default-inline \
				   -fkeep-inline-functions -fno-elide-constructors  \
           -ftest-coverage -O0 -fsanitize=address \
					 -std=c++17 -stdlib=libc++ -lc++ -lc++abi \
           -o $(TEST_EXEC) $(OBJECT_FILES)
	@printf '$(GREEN)Test Executable Generated!$(RESET)\n'

%.hpp.gch: %.hpp
	@printf '$(YELLOW)Precompiling file (h++) $(RESET): $< '
	@mkdir -p "$(dir $@)"
	@$(CPPC) $(CFLAGS) -std=c++17 -stdlib=libc++ -MF"$(@:%.o=%.d)" -MT"$(@)" \
	      -o "$@" $(LIB_DIR)/L5_Testing/testing_frameworks.hpp
	@printf '$(GREEN)DONE!$(RESET)\n'

%.lint: %
	@printf '$(YELLOW)Evaluating file: $(RESET)$< '
	@$(CLANG_TIDY) $(if $(or $(findstring .hpp,$<), $(findstring .cpp,$<)), \
	  -extra-arg="-std=c++17") "$<"  -- \
		-D CLANG_TIDY=1 -D HOST_TEST=1 \
		-isystem"$(SJCLANG)/../include/c++/v1/" \
		-stdlib=libc++ $(INCLUDES) 2> /dev/null
	@printf '$(GREEN)DONE!$(RESET)\n'
