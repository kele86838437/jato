/*
 * Copyright (C) 2006  Pekka Enberg
 */

#include <vm/system.h>
#include <vm/vm.h>
#include <jit/jit-compiler.h>
#include <libharness.h>
#include <basic-block-assert.h>

/* public String defaultString(String s) { if (s == null) { s = ""; } return s; } */
static unsigned char default_string[9] = {
	/* 0 */ OPC_ALOAD_1,
	/* 1 */ OPC_IFNONNULL, 0x00, 0x06, /* Jumps to 0x07 */
	
	/* 4 */ OPC_LDC, 0x02,
	/* 6 */ OPC_ASTORE_1,

	/* 7 */ OPC_ALOAD_1,
	/* 8 */ OPC_ARETURN,
};

void test_branch_opcode_ends_basic_block(void)
{
	struct basic_block *bb1, *bb2, *bb3;
	struct compilation_unit *cu;
	struct methodblock method = {
		.jit_code = default_string,
		.code_size = ARRAY_SIZE(default_string)
	};
	
	cu = alloc_compilation_unit(&method);

	analyze_control_flow(cu);

	assert_int_equals(3, nr_bblocks(cu));

	bb1 = bb_entry(cu->bb_list.next);
	bb2 = bb_entry(bb1->bb_list_node.next);
	bb3 = bb_entry(bb2->bb_list_node.next);

	assert_basic_block(cu, 0, 4, bb1);
	assert_basic_block(cu, 4, 7, bb2);
	assert_basic_block(cu, 7, 9, bb3);

	assert_basic_block_successors(bb2, bb3, bb1);
	assert_basic_block_successors(bb3, NULL, bb2);
	assert_basic_block_successors(NULL, NULL, bb3);

	free_compilation_unit(cu);
}

/* public boolean greaterThanZero(int i) { return i > 0; } */ 
static unsigned char greater_than_zero[10] = {
	/* 0 */ OPC_ILOAD_1,
	/* 1 */ OPC_IFLE, 0x00, 0x07,

	/* 4 */ OPC_ICONST_1,
	/* 5 */ OPC_GOTO, 0x00, 0x04,

	/* 8 */ OPC_ICONST_0,

	/* 9 */ OPC_IRETURN,
};

void test_multiple_branches(void)
{
	struct basic_block *bb1, *bb2, *bb3, *bb4;
	struct compilation_unit *cu;

	struct methodblock method = {
		.jit_code = greater_than_zero,
		.code_size = ARRAY_SIZE(greater_than_zero) 
	};

	cu = alloc_compilation_unit(&method);

	analyze_control_flow(cu);
	assert_int_equals(4, nr_bblocks(cu));

	bb1 = bb_entry(cu->bb_list.next);
	bb2 = bb_entry(bb1->bb_list_node.next);
	bb3 = bb_entry(bb2->bb_list_node.next);
	bb4 = bb_entry(bb3->bb_list_node.next);

	assert_basic_block_successors(bb2, bb3, bb1);
	assert_basic_block_successors(bb4, NULL, bb2);
	assert_basic_block_successors(bb4, NULL, bb3);
	assert_basic_block_successors(NULL, NULL, bb4);

	free_compilation_unit(cu);
}
