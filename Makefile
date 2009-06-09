CLASSPATH_CONFIG = tools/classpath-config

JAMVM_INSTALL_DIR	:= /usr/local
CLASSPATH_INSTALL_DIR	?= $(shell ./tools/classpath-config)

GLIBJ		= $(CLASSPATH_INSTALL_DIR)/share/classpath/glibj.zip
BOOTCLASSPATH	= lib/classes.zip:$(GLIBJ)

BUILD_ARCH	:= $(shell uname -m | sed -e s/i.86/i386/)
ARCH		:= $(BUILD_ARCH)
JAMVM_ARCH	:= $(shell echo "$(ARCH)" | sed -e s/ppc/powerpc/)
OS		:= $(shell uname -s | tr "[:upper:]" "[:lower:]")

ifneq ($(ARCH),$(BUILD_ARCH))
TEST		=
else
TEST		= test
endif

ifeq ($(ARCH),i386)
override ARCH	= x86
ARCH_POSTFIX	= _32
ifeq ($(BUILD_ARCH),x86_64)
ARCH_CFLAGS	+= -m32
TEST		= test
endif
endif

ifeq ($(ARCH),x86_64)
override ARCH	= x86
ARCH_POSTFIX	= _64
endif

ifeq ($(ARCH),ppc)
override ARCH	= ppc
ARCH_POSTFIX	= _32
endif

export ARCH_CFLAGS

ARCH_CONFIG=arch/$(ARCH)/include/arch/config$(ARCH_POSTFIX).h

# Make the build silent by default
V =

PROGRAM		:= jato

include arch/$(ARCH)/Makefile$(ARCH_POSTFIX)

JIT_OBJS = \
	jit/alloc.o		\
	jit/arithmetic-bc.o	\
	jit/basic-block.o	\
	jit/branch-bc.o		\
	jit/bytecode-to-ir.o	\
	jit/cfg-analyzer.o	\
	jit/compilation-unit.o	\
	jit/compiler.o		\
	jit/disass-common.o	\
	jit/emit.o		\
	jit/emulate.o		\
	jit/expression.o	\
	jit/args.o		\
	jit/interval.o		\
	jit/invoke-bc.o		\
	jit/linear-scan.o	\
	jit/liveness.o		\
	jit/load-store-bc.o	\
	jit/exception-bc.o	\
	jit/object-bc.o		\
	jit/ostack-bc.o		\
	jit/stack-slot.o	\
	jit/statement.o		\
	jit/spill-reload.o	\
	jit/trace-jit.o		\
	jit/trampoline.o	\
	jit/tree-printer.o	\
	jit/typeconv-bc.o	\
	jit/vtable.o		\
	jit/fixup-site.o	\
	jit/exception.o 	\
	jit/bc-offset-mapping.o \
	jit/cu-mapping.o	\
	jit/method.o		\
	jit/nop-bc.o		\
	jit/tree-node.o		\
	jit/perf-map.o

VM_OBJS = \
	vm/bitset.o		\
	vm/buffer.o		\
	vm/bytecode.o		\
	vm/bytecodes.o		\
	vm/debug-dump.o		\
	vm/die.o		\
	vm/natives.o		\
	vm/resolve.o		\
	vm/signal.o		\
	vm/stack.o		\
	vm/string.o		\
	vm/types.o		\
	vm/zalloc.o		\
	vm/class.o		\
	vm/list.o 		\
	vm/radix-tree.o		\
	vm/guard-page.o

JAMVM_OBJS = \
	vm/jato.o		\
	jamvm/access.o		\
	jamvm/alloc.o		\
	jamvm/cast.o		\
	jamvm/class.o		\
	jamvm/direct.o		\
	jamvm/dll.o		\
	jamvm/dll_ffi.o		\
	jamvm/excep.o		\
	jamvm/execute.o		\
	jamvm/frame.o		\
	jamvm/hash.o		\
	jamvm/hooks.o		\
	jamvm/init.o		\
	jamvm/interp.o		\
	jamvm/jni.o		\
	jamvm/lock.o		\
	jamvm/natives.o		\
	jamvm/properties.o	\
	jamvm/reflect.o		\
	jamvm/resolve.o		\
	jamvm/string.o		\
	jamvm/thread.o		\
	jamvm/utf8.o		\
	jamvm/zip.o

LIBHARNESS_OBJS = \
	test/libharness/libharness.o

JATO_OBJS = $(ARCH_OBJS) $(JIT_OBJS) $(VM_OBJS)

OBJS = $(JAMVM_OBJS) $(JATO_OBJS)

AS		:= as
CC		:= gcc
MONOBURG	:= ./monoburg/monoburg
JAVAC		:= ecj

DEFAULT_CFLAGS	+= $(ARCH_CFLAGS) -g -Wall -rdynamic -std=gnu99 -D_GNU_SOURCE

WARNINGS	= -Wsign-compare -Wundef
DEFAULT_CFLAGS	+= $(WARNINGS)

OPTIMIZATIONS	+= -Os
DEFAULT_CFLAGS	+= $(OPTIMIZATIONS)

INCLUDES	= -Iinclude -Iarch/$(ARCH)/include -Ijit -Ijamvm -Ijit/glib -include $(ARCH_CONFIG)
DEFAULT_CFLAGS	+= $(INCLUDES)

DEFINES = -DINSTALL_DIR=\"$(JAMVM_INSTALL_DIR)\" -DCLASSPATH_INSTALL_DIR=\"$(CLASSPATH_INSTALL_DIR)\"
DEFAULT_CFLAGS	+= $(DEFINES)

DEFAULT_LIBS	= -lpthread -lm -ldl -lz -lbfd -lopcodes -liberty $(ARCH_LIBS)

JAMVM_ARCH_H = include/vm/arch.h

all: $(PROGRAM) $(TEST)
.PHONY: all
.DEFAULT: all

$(CLASSPATH_CONFIG):
	$(E) "  LD      " $@
	$(Q) $(CC) -Wall $(CLASSPATH_CONFIG).c -o $(CLASSPATH_CONFIG)

monoburg:
	$(Q) make -C monoburg/
.PHONY: monoburg

%.o: %.c
	$(E) "  CC      " $@
	$(Q) $(CC) -c $(DEFAULT_CFLAGS) $(CFLAGS) $< -o $@
	$(Q) $(CC) -MM $(DEFAULT_CFLAGS) $(CFLAGS) -MT $@ $*.c -o $*.d

%.o: %.S
	$(E) "  AS      " $@
	$(Q) $(AS) $(AFLAGS) $< -o $@

$(JAMVM_ARCH_H):
	$(E) "  LN      " $@
	$(Q) ln -fsn ../../jamvm/arch/$(JAMVM_ARCH).h $@

arch/$(ARCH)/insn-selector$(ARCH_POSTFIX).c: FORCE
	$(E) "  MONOBURG" $@
	$(Q) $(MONOBURG) -p -e $(@:.c=.brg) > $@

$(PROGRAM): lib monoburg $(JAMVM_ARCH_H) compile
	$(E) "  CC      " $@
	$(Q) $(CC) $(DEFAULT_CFLAGS) $(CFLAGS) $(OBJS) -o $(PROGRAM) $(LIBS) $(DEFAULT_LIBS)

compile: $(OBJS)

test: $(JAMVM_ARCH_H) monoburg
	make -C test/vm/ ARCH=$(ARCH) ARCH_POSTFIX=$(ARCH_POSTFIX) $(TEST)
	make -C test/jit/ ARCH=$(ARCH) ARCH_POSTFIX=$(ARCH_POSTFIX) $(TEST)
	make -C test/arch-$(ARCH)/ ARCH=$(ARCH) ARCH_POSTFIX=$(ARCH_POSTFIX) $(TEST)
.PHONY: test

%.class: %.java
	$(E) "  JAVAC   " $@
	$(Q) $(JAVAC) -cp $(BOOTCLASSPATH):regression -d regression $<

REGRESSION_TEST_SUITE_CLASSES = \
	regression/jato/internal/VM.class \
	regression/jvm/TestCase.class \
	regression/jvm/ExitStatusIsOneTest.class \
	regression/jvm/ExitStatusIsZeroTest.class \
	regression/jvm/LoadConstantsTest.class \
	regression/jvm/IntegerArithmeticTest.class \
	regression/jvm/LongArithmeticTest.class \
	regression/jvm/ObjectCreationAndManipulationTest.class \
	regression/jvm/ControlTransferTest.class \
	regression/jvm/SynchronizationTest.class \
	regression/jvm/MethodInvocationAndReturnTest.class \
	regression/jvm/ConversionTest.class \
	regression/jvm/PutstaticTest.class \
	regression/jvm/PutfieldTest.class \
	regression/jvm/TrampolineBackpatchingTest.class \
	regression/jvm/RegisterAllocatorTortureTest.class \
	regression/jvm/ExceptionsTest.class \
	regression/jvm/FibonacciTest.class \
	regression/jvm/ObjectStackTest.class

lib: $(CLASSPATH_CONFIG)
	make -C lib/ JAVAC=$(JAVAC) GLIBJ=$(GLIBJ)
.PHONY: lib

regression: monoburg $(CLASSPATH_CONFIG) lib $(PROGRAM) $(REGRESSION_TEST_SUITE_CLASSES)
	$(E) "  REGRESSION"
	$(Q) cd regression && /bin/bash run-suite.sh $(JAVA_OPTS)
.PHONY: regression

clean:
	$(E) "  CLEAN"
	$(Q) - rm -f $(PROGRAM)
	$(Q) - rm -f $(CLASSPATH_CONFIG)
	$(Q) - rm -f $(OBJS)
	$(Q) - rm -f $(OBJS:.o=.d)
	$(Q) - rm -f $(LIBHARNESS_OBJS)
	$(Q) - rm -f $(ARCH_TEST_OBJS)
	$(Q) - rm -f arch/$(ARCH)/insn-selector.c
	$(Q) - rm -f $(PROGRAM)
	$(Q) - rm -f $(JAMVM_ARCH_H)
	$(Q) - rm -f $(ARCH_TEST_SUITE)
	$(Q) - rm -f test-suite.o
	$(Q) - rm -f $(ARCH_TESTRUNNER)
	$(Q) - rm -f $(REGRESSION_TEST_SUITE_CLASSES)
	$(Q) - find regression/ -name "*.class" | xargs rm -f
	$(Q) - rm -f tags
	$(Q) - rm -f include/arch
	$(Q) - make -C monoburg/ clean
	$(Q) - make -C test/vm/ clean
	$(Q) - make -C test/jit/ clean
	$(Q) - make -C test/arch-$(ARCH)/ clean
	$(Q) - make -C lib clean
.PHONY: clean

PHONY += FORCE
FORCE:

include scripts/build/common.mk

-include $(OBJS:.o=.d)
