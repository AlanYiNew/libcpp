# Targets
TARGETS := libc++ libc++abi libunwind

include $(SEL4_COMMON)/common.mk

CFLAGS := $(CFLAGS) $(CPPFLAGS)
CXXFLAGS := $(filter-out -I$(STAGE_DIR)/include/c++/v1,$(CXXFLAGS) $(CPPFLAGS))

# cmake tries to link during config despite nothing needing the linker in the
# actual build, but causes problems due to missing libraries, so we ignore all
# unresolved symbols
LDFLAGS := -Wl,--unresolved-symbols=ignore-all

.PHONY: libc++ libc++abi libunwind

$(SOURCE_DIR)/llvm/CMakeLists.txt:
	mkdir -p "$(SOURCE_DIR)/llvm"
	# No HTTPS gosh :(
	curl "http://releases.llvm.org/3.9.1/llvm-3.9.1.src.tar.xz" | tar xJf - -C "$(SOURCE_DIR)/llvm" --strip-components=1

$(SOURCE_DIR)/libcxx/CMakeLists.txt: | $(SOURCE_DIR)/libcxx-sos.patch
	mkdir -p "$(SOURCE_DIR)/libcxx"
	curl "http://releases.llvm.org/3.9.1/libcxx-3.9.1.src.tar.xz" | tar xJf - -C "$(SOURCE_DIR)/libcxx" --strip-components=1
	(cd "$(SOURCE_DIR)/libcxx" && patch -mp1 < ../libcxx-sos.patch)

$(SOURCE_DIR)/libcxxabi/CMakeLists.txt: | $(SOURCE_DIR)/libcxxabi-sos.patch
	mkdir -p "$(SOURCE_DIR)/libcxxabi"
	curl "http://releases.llvm.org/3.9.1/libcxxabi-3.9.1.src.tar.xz" | tar xJf - -C "$(SOURCE_DIR)/libcxxabi" --strip-components=1
	(cd "$(SOURCE_DIR)/libcxxabi" && patch -mp1 < ../libcxxabi-sos.patch)

$(SOURCE_DIR)/libunwind/CMakeLists.txt:
	mkdir -p "$(SOURCE_DIR)/libunwind"
	curl "http://releases.llvm.org/3.9.1/libunwind-3.9.1.src.tar.xz" | tar xJf - -C "$(SOURCE_DIR)/libunwind" --strip-components=1

libc++: $(SOURCE_DIR)/llvm/CMakeLists.txt $(SOURCE_DIR)/libcxx/CMakeLists.txt $(SOURCE_DIR)/libcxxabi/CMakeLists.txt
	mkdir -p "$(BUILD_DIR)/libcxx"
	@echo $(values CXXFLAGS)
	cd "$(BUILD_DIR)/libcxx" && \
		cmake \
			-DCMAKE_SYSTEM_NAME=Generic \
			-DCMAKE_SYSTEM_PROCESSOR=arm-eabi \
			-DCMAKE_C_COMPILER="$(strip $(CC))" \
			-DCMAKE_CXX_COMPILER="$(strip $(CXX))" \
	        -DLLVM_PATH="$(SOURCE_DIR)/llvm" \
			-DLIBCXX_HAS_MUSL_LIBC=on \
	        -DLIBCXX_ENABLE_THREADS=on \
			-DLIBCXX_CXX_ABI=libcxxabi \
			-DLIBCXX_STANDARD_VER=c++14 \
	        -DLIBCXX_CXX_ABI_INCLUDE_PATHS="$(SOURCE_DIR)/libcxxabi/include" \
			-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=on \
			-DLIBCXXABI_USE_LLVM_UNWINDER=on \
			-DLIBCXX_ENABLE_SHARED=off \
			-DCMAKE_INSTALL_PREFIX="$(STAGE_DIR)" \
			-DUNIX=1 \
			"$(SOURCE_DIR)/libcxx" && \
		$(MAKE) -j && $(MAKE) install

libc++abi:  $(SOURCE_DIR)/llvm/CMakeLists.txt $(SOURCE_DIR)/libcxx/CMakeLists.txt $(SOURCE_DIR)/libcxxabi/CMakeLists.txt $(SOURCE_DIR)/libunwind/CMakeLists.txt
	mkdir -p "$(BUILD_DIR)/libcxxabi"
	cd "$(BUILD_DIR)/libcxxabi" && \
		cmake \
			-DCMAKE_SYSTEM_NAME=Generic \
			-DCMAKE_SYSTEM_PROCESSOR=arm-eabi \
			-DCMAKE_C_COMPILER="$(strip $(CC))" \
			-DCMAKE_CXX_COMPILER="$(strip $(CXX))" \
	        -DLLVM_PATH="$(SOURCE_DIR)/llvm" \
			-DLIBCXXABI_LIBCXX_PATH="$(SOURCE_DIR)/libcxx" \
			-DLIBCXXABI_LIBUNWIND_PATH="$(SOURCE_DIR)/libunwind" \
			-DLIBCXXABI_USE_LLVM_UNWINDER=on \
			-DLIBCXXABI_ENABLE_SHARED=off \
			-DCMAKE_INSTALL_PREFIX="$(STAGE_DIR)" \
			-DUNIX=1 \
			-DLLVM_FORCE_USE_OLD_TOOLCHAIN=1 \
			"$(SOURCE_DIR)/libcxxabi" && \
		$(MAKE) -j && $(MAKE) install

libunwind:  $(SOURCE_DIR)/llvm/CMakeLists.txt
	mkdir -p "$(BUILD_DIR)/libunwind"
	cd "$(BUILD_DIR)/libunwind" && \
		CXXFLAGS="-I$(STAGE_DIR)/include/c++/v1 $(CXXFLAGS)" cmake \
			-DCMAKE_SYSTEM_NAME=Generic \
			-DCMAKE_SYSTEM_PROCESSOR=arm-eabi \
			-DCMAKE_C_COMPILER="$(strip $(CC))" \
			-DCMAKE_CXX_COMPILER="$(strip $(CXX))" \
			-DLLVM_PATH="$(SOURCE_DIR)/llvm" \
			-DLIBUNWIND_ENABLE_SHARED=off \
			-DCMAKE_INSTALL_PREFIX="$(STAGE_DIR)" \
			-DUNIX=1 \
			-DLLVM_FORCE_USE_OLD_TOOLCHAIN=1 \
			"$(SOURCE_DIR)/libunwind" && \
		$(MAKE) -j && $(MAKE) install
