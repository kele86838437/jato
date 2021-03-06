#ifndef JATO__ARM_INSTRUCTION_H
#define JATO__ARM_INSTRUCTION_H

#include "jit/constant-pool.h"
#include "jit/use-position.h"

#include "arch/stack-frame.h"
#include "arch/registers.h"
#include "arch/init.h"

#include "lib/list.h"
#include "vm/die.h"

#include <stdbool.h>

struct compilation_unit;
struct resolution_block;
struct basic_block;
struct bitset;

enum operand_type {
	OPERAND_BRANCH_TARGET,
	OPERAND_IMM,
	OPERAND_MEMLOCAL,
	/* This operand is required by constant pool implementation */
	OPERAND_LITERAL_POOL,
	OPERAND_REG,
	/* This must be last */
	LAST_OPERAND
};

struct operand {
	enum operand_type type;
	union {
		struct use_position reg;

		struct {
			struct use_position base_reg;
			union {
				long disp;	/* displacement */
				struct {
					struct use_position index_reg;
					unsigned char shift;
				};
			};
		};

		struct stack_slot *slot; /* FP + displacement */

		struct lp_entry *pool; /* PC + displacement */

		uint8_t imm;	/* In arm we have 8-bit immediate only */

		struct basic_block *branch_target;

		struct resolution_block *resolution_block;
	};
};

static inline bool operand_is_reg(struct operand *operand)
{
	switch (operand->type) {
	case OPERAND_IMM:
	case OPERAND_MEMLOCAL:
	case OPERAND_BRANCH_TARGET:
		return false;
	case OPERAND_REG:
	case OPERAND_LITERAL_POOL:
		return true;
	default:
		assert(!"invalid operand type");
	}
	return false;
}

/*
 *	Instruction type identifies the opcode, number of operands, and
 *	operand types.
 */
enum insn_type {
	INSN_ADD_REG_IMM,
	INSN_ADC_REG_IMM,
	INSN_ADD_REG_REG,
	INSN_ADC_REG_REG,
	INSN_ADDS_REG_IMM,
	INSN_ADDS_REG_REG,
	INSN_LDR_REG_MEMLOCAL,
	INSN_MOV_REG_IMM,
	INSN_MOV_REG_REG,
	INSN_MVN_REG_IMM,
	/*

	 * This instruction is not an actual instruction, it is
	 * required by constant literal pool implementation
	 */
	INSN_LDR_REG_POOL_IMM,
	INSN_PHI,
	INSN_STR_MEMLOCAL_REG,
	INSN_SUB_REG_IMM,
	INSN_SBC_REG_IMM,
	INSN_SBC_REG_REG,
	INSN_SUBS_REG_IMM,
	INSN_SUB_REG_REG,
	INSN_SUBS_REG_REG,
	INSN_UNCOND_BRANCH,
	/* Must be last */
	NR_INSN_TYPES,
};

enum insn_flag_type {
	INSN_FLAG_ESCAPED		= 1U << 0,
	INSN_FLAG_SAFEPOINT		= 1U << 1,
	INSN_FLAG_KNOWN_BC_OFFSET	= 1U << 2,
	INSN_FLAG_RENAMED		= 1U << 3, /* instruction with renamed virtual registers */
	INSN_FLAG_SSA_ADDED		= 1U << 4, /* instruction added during SSA deconstruction */
	INSN_FLAG_BACKPATCH_BRANCH	= 1U << 5,
	INSN_FLAG_BACKPATCH_RESOLUTION	= 1U << 6,
};

struct insn {
	uint8_t			type;		 /* see enum insn_type */
	uint8_t			flags;		 /* see enum insn_flag_type */
	uint16_t		bc_offset;	 /* offset in bytecode */
	uint32_t		mach_offset;	 /* offset in machine code */
	uint32_t		lir_pos;	 /* offset in LIR */
	struct list_head	insn_list_node;

	union {
		struct {
			struct operand src;
			struct operand dest;
		};
		struct {
			struct operand *ssa_srcs;
			struct operand ssa_dest;
			unsigned long nr_srcs;
		};

		struct operand operand;
	};
};

#define MAX_REG_OPERANDS 4

void insn_sanity_check(void);

struct insn *insn(enum insn_type);
struct insn *reg_imm_insn(enum insn_type, unsigned long, struct var_info *);
struct insn *reg_pool_insn(enum insn_type, struct lp_entry *, struct var_info *);
struct insn *reg_memlocal_insn(enum insn_type, struct stack_slot *, struct var_info *);
struct insn *memlocal_reg_insn(enum insn_type, struct var_info *, struct stack_slot *);
struct insn *reg_reg_insn(enum insn_type, struct var_info *, struct var_info *);
struct insn *branch_insn(enum insn_type, struct basic_block *);

/*
 * These functions are used by generic code to insert spill/reload
 * instructions.
 */

int insert_copy_slot_32_insns(struct stack_slot *, struct stack_slot *,
					struct list_head *, unsigned long);
int insert_copy_slot_64_insns(struct stack_slot *, struct stack_slot *,
					struct list_head *, unsigned long);

struct insn *spill_insn(struct var_info *var, struct stack_slot *slot);
struct insn *reload_insn(struct stack_slot *slot, struct var_info *var);
struct insn *jump_insn(struct basic_block *bb);

bool insn_is_branch(struct insn *insn);
bool insn_is_jmp_branch(struct insn *insn);
bool insn_is_call(struct insn *insn);

static inline bool insn_is_call_to(struct insn *insn, void *target)
{
	assert(!"not implemented");

	return false;
}

int ssa_modify_insn_type(struct insn *);
void imm_operand(struct operand *, unsigned long);

#endif /* JATO__ARM_INSTRUCTION_H */
