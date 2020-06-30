include $(LIBRARY_DIR)/third_party/microrl/microrl.mk
include $(LIBRARY_DIR)/third_party/printf/printf.mk
include $(LIBRARY_DIR)/third_party/semihost/semihost.mk
include $(LIBRARY_DIR)/third_party/fatfs/fatfs.mk

LIBRARY_3P += $(LIBRARY_DIR)/third_party/unity.c
LIBRARY_3P += $(LIBRARY_DIR)/third_party/unity.cpp

$(eval $(call BUILD_LIBRARY,libthirdparty,LIBRARY_3P))
