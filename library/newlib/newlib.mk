INCLUDES +=
SYSTEM_INCLUDES +=

LIBRARY_NEWLIB += $(LIBRARY_DIR)/newlib/newlib.cpp

TESTS += $(LIBRARY_DIR)/newlib/newlib.cpp
USER_TESTS += $(LIBRARY_DIR)/newlib/newlib.cpp

# TODO(#435): Consider adding this library to static libraries
$(eval $(call BUILD_LIRBARY,libnewlib,LIBRARY_NEWLIB))
